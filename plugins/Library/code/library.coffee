# заполнить разделы читальни
хранилище.create_collection('library_categories', [['название', no], ['надраздел', no]])

# пути разделов и заметок
хранилище.create_collection('library_paths', [['путь', yes], ['раздел', no], ['заметка', no]])

# заметки
хранилище.create_collection('library_articles', [['название', no], ['раздел', no]])

library = require(__dirname + '/library tools')

http.get '/читальня/раздел/путь', (ввод, вывод) ->
	_id = db('library_categories').id(ввод.данные._id)
	
	вывод.send(путь: читальня.путь_к_разделу(_id))
	
http.get '/читальня/раздел', (ввод, вывод) ->
	_id = ввод.данные._id
	
	$ = {}
	
	$.раздел = {}
		
	# получить подразделы
	
	query = null

	if _id?
		$.раздел = db('library_categories')._.find_one({ _id: db('library_categories').id(_id) })
	
		if not $.раздел?
			throw "Раздел не найден"
		
		# мы находимся на странице некоего раздела читальни
		query = { надраздел: $.раздел._id }
	else
		# мы находимся на главной странице читальни
		query = { надраздел: { $exists: 0 } }
		
	подразделы = db('library_categories')._.find(query, { sort: [['_id', 1]] })

	$.раздел.подразделы = подразделы
	
	for подраздел in подразделы
		подраздел.путь = читальня.путь_к_разделу(подраздел._id)
		
	# получить заметки
		
	query = null
	
	if not _id?
		# мы находимся на главной странице читальни
		# (там заметок быть не должно)
		query = { раздел: { $exists: 0 } }
	else
		# мы находимся на странице некоего раздела читальни
		query = { раздел: $.раздел._id }

	заметки = db('library_articles')._.find(query, { sort: [['_id', 1]] })

	$.раздел.заметки = заметки

	for заметка in заметки
		заметка.путь = читальня.путь_к_заметке(заметка._id)

	вывод.send($)

http.get "/читальня/заметка", (ввод, вывод) ->
	_id = db('library_articles').id(ввод.данные._id)

	заметка = db('library_articles')._.find_one({ _id: _id })
			
	if not заметка?
		throw "Заметка не найдена"
	
	вывод.send(заметка: заметка)
			
http.get "/раздел или заметка", (ввод, вывод) ->
	раздел_или_заметка = db('library_paths')._.find_one({ путь: ввод.данные.путь })
			
	if not раздел_или_заметка?
		ошибка = 
			текст: "not found"
			уровень: 'ничего страшного'
			показать: no
			
		throw ошибка
	
	if раздел_или_заметка.заметка?
		return вывод.send(заметка: раздел_или_заметка.заметка)
	else
		return вывод.send(раздел: раздел_или_заметка.раздел)
	
http.post '/сеть/читальня/заметка', (ввод, вывод, пользователь) ->
	_id = db('library_articles').id(ввод.данные._id)
	версия = ввод.данные.версия
	
	название = ввод.данные.название
	содержимое = ввод.данные.содержимое
	
	заметка = db('library_articles')._.find_one({ _id: _id })
			
	путь = null
			
	if заметка.название != название
		заметка.название = название
		путь = читальня.создать_путь_к_заметке(заметка).путь
	
	query = { _id: _id }
	
	if версия?
		query.версия = parseInt(версия)
	else
		query.версия = { $exists: 0 }
	
	result = db('library_articles')._.update(query, { $set: { название: название, содержимое: содержимое }, $inc: { версия: 1 } })
	
	if result != 1
		return вывод.send({ старая_версия: yes })
	
	заметка = db('library_articles')._.find_one({ _id: _id })
	
	if путь?
		заметка.путь = путь
		
	вывод.send(заметка)
						
http.post '/сеть/читальня/раздел', (ввод, вывод, пользователь) ->
	разделы = JSON.parse(ввод.данные.разделы)
	заметки = JSON.parse(ввод.данные.заметки)
	
	надраздел = null
	if ввод.данные.надраздел?
		надраздел = db('library_categories').id(ввод.данные.надраздел)
			
	# проверить занятость названий
	
	for раздел in разделы.новые
		data = { название: раздел.название }
		
		if надраздел?
			data.надраздел = надраздел
			
		if db('library_categories')._.find_one(data)?
			throw 'Раздел с таким именем уже есть в этом надразделе: ' + раздел.название
	
	# удалить удалённые разделы

	for раздел in разделы.удалённые
		_id = db('library_categories').id(раздел)
		читальня.delete_category_recursive(_id, пользователь)
	
	# удалить удалённые заметки

	for заметка in заметки.удалённые
		_id = db('library_articles').id(заметка)
		читальня.delete_article(_id, пользователь)
	
	# обновить обновлённые картинки разделов

	for раздел in разделы.обновлённые_картинки
		_id = db('library_categories').id(раздел._id)
		
		options =
			временное_название: раздел.icon
			место: '/читальня/разделы/' + раздел._id
			название: 'обложка'
			extra_sizes: { 'крошечная обложка': { размер: Options.Library.Category.Icon.Tiny.Size } }
	
		finish_picture_upload(options)
				
		db('library_categories')._.update({ _id: _id }, { $inc: { 'icon_version': 1 } })

	# переупорядочить переупорядоченные разделы
	
	переупорядоченные_разделы = разделы.переупорядоченные.map((x) ->
		{ _id: db('library_categories').id(x._id), порядок: x.порядок }
	)
	
	for раздел in переупорядоченные_разделы
		db('library_categories')._.update({ _id: раздел._id }, { $set: { порядок: раздел.порядок } })
	
	# переупорядочить переупорядоченные заметки
	
	переупорядоченные_заметки = заметки.переупорядоченные.map((x) ->
		{ _id: db('library_articles').id(x._id), порядок: x.порядок }
	)
	
	for заметка in переупорядоченные_заметки
		db('library_articles')._.update({ _id: заметка._id }, { $set: { порядок: заметка.порядок } })
	
	# переименовать переименованные	
		
	переименованные_разделы = разделы.переименованные.map((x) ->
		{ _id: db('library_categories').id(x._id), название: x.название }
	)
	
	for раздел in переименованные_разделы
		if надраздел?
			раздел.надраздел = надраздел
			
		путь = читальня.rename_category(раздел)
		
		раздел._id = раздел._id.toString()
		раздел.путь = путь
				
	# создать новые

	новые_разделы = []
		
	for раздел in разделы.новые
		if надраздел?
			раздел.надраздел = надраздел
			
		новые_разделы.add(db('library_categories')._.save(раздел, { safe: yes }))
		
	for раздел in новые_разделы
		раздел.путь = читальня.создать_путь_к_разделу(раздел, раздел.надраздел)
		
	# всё
	
	вывод.send({})
	
	# это отправлялось на случай обновления view без перезагрузки страницы,
	# но это может внести неучтённые ошибки, поэтому пока просто перезагружается страница после сохранения
	#result = 
	#	новые_разделы: JSON.stringify(новые_разделы)
	#	переименованные_разделы: JSON.stringify(переименованные_разделы)
	#	удалённые_разделы: JSON.stringify(разделы.удалённые)
	
	#вывод.send(result)
			
http.post '/сеть/читальня/раздел/перенести', (ввод, вывод, пользователь) ->
	раздел = db('library_categories').id(ввод.данные.раздел)
	
	action = null
	
	output = {}
	
	последний = null
	
	if ввод.данные.куда?
		куда = db('library_categories').id(ввод.данные.куда)
	
		if (куда + '' == раздел + '')
			throw 'Нельзя перенести раздел сам в себя'
		
		if ввод.данные.куда?
			output.путь = db('library_paths')._.find_one({ раздел: куда }).путь
		
		последний = db('library_categories')._.find_just_one({ надраздел: куда }, { sort: [['порядок', -1]] })
	
		action =
			$set:
				надраздел: куда
	else
		последний = db('library_categories')._.find_just_one({ надраздел: { $exists: 0 } }, { sort: [['порядок', -1]] })
	
		action =
			$unset:
				надраздел: 1
			
	action.$set = action.$set || {}
			
	if последний? && последний.порядок?
		action.$set.порядок = последний.порядок + 1
	else
		action.$set.порядок = 1

	result = db('library_categories')._.update({ _id: раздел }, action)
	
	if result != 1
		throw 'Ошибка перенесения раздела'
	
	раздел = db('library_categories')._.find_one({ _id: раздел })
	
	путь = читальня.обновить_пути(раздел)
	
	вывод.send(output)
			
http.put '/сеть/читальня/заметка', (ввод, вывод, пользователь) ->
	название = ввод.данные.название.trim()
	содержимое = ввод.данные.содержимое
	раздел = db('library_categories').id(ввод.данные.раздел)
	
	заметка = db('library_articles')._.find_one({ название: название, раздел: раздел })
	
	if заметка?
		throw 'Заметка с таким именем уже есть в этом разделе'

	порядок = 1
	последняя_по_порядку = db('library_articles')._.find_just_one({ раздел: раздел }, { sort: [['порядок', -1]] })
	if последняя_по_порядку?
		порядок = последняя_по_порядку.порядок + 1
		
	заметка = db('library_articles')._.save({ название: название, содержимое: содержимое, раздел: раздел, порядок: порядок })
	
	путь = читальня.создать_путь_к_заметке(заметка)
	
	вывод.send({ путь: путь.путь })
			
http.delete '/сеть/читальня/заметка', (ввод, вывод, пользователь) ->
	_id = db('library_articles').id(ввод.данные._id)
	
	заметка = db('library_articles')._.find_one({ _id: _id })
			
	путь_к_разделу = читальня.путь_к_разделу(заметка.раздел)
			
	читальня.delete_article(заметка, пользователь)
			
	вывод.send(путь_к_разделу: путь_к_разделу)
			
http.post '/сеть/читальня/заметка/перенести', (ввод, вывод, пользователь) ->
	_id = db('library_articles').id(ввод.данные.заметка)

	action = null
	
	if not ввод.данные.куда?
		throw 'Нельзя перемещать заметки в корень читальни'
	
	куда = db('library_categories').id(ввод.данные.куда)
	
	action =
		$set:
			раздел: куда
			
	последняя = db('library_articles')._.find_just_one({ раздел: куда }, { sort: [['порядок', -1]] })

	if последняя? && последняя.порядок?
		action.$set.порядок = последняя.порядок + 1
	else
		action.$set.порядок = 1

	result = db('library_articles')._.update({ _id: _id }, action)
				
	if result != 1
		throw 'Ошибка перенесения заметки'
	
	заметка = db('library_articles')._.find_one({ _id: _id })
	
	путь = db('library_paths')._.find_one({ раздел: куда }).путь
	читальня.создать_путь_к_заметке(заметка)
	
	вывод.send({ путь: путь })
	
# поиск в читальне. пока не используется
http.get '/читальня/поиск', (ввод, вывод) ->
	шаблон = '.*' + RegExp.escape(ввод.данные.query) + '.*'
	
	query = { название: { $regex: шаблон, $options: 'i' } }
	options = { limit: ввод.данные.max }
	
	разделы = db('library_categories')._.find(query, options)
	заметки = db('library_articles')._.find(query, options)
	
	too_much = ->
		return разделы.length + заметки.length > ввод.данные.max
	
	while too_much()
		заметки.shift()
		if too_much()
			разделы.shift()
	
	for раздел in разделы
		раздел.путь = читальня.путь_к_разделу(раздел._id)
		
	for заметка in заметки
		заметка.путь = читальня.путь_к_заметке(заметка._id)
		
	Object.выбрать(['_id', 'путь', 'название', 'icon_version'], разделы)
	Object.выбрать(['_id', 'путь', 'название'], заметки)
	
	вывод.send(разделы: разделы, заметки: заметки)
	
http.get '/читальня/разделы/найти', (ввод, вывод) ->
	шаблон = '.*' + RegExp.escape(ввод.данные.query) + '.*'
	
	разделы = db('library_categories')._.find({ название: { $regex: шаблон, $options: 'i' } }, { limit: ввод.данные.max })
	
	Object.выбрать(['_id', 'название', 'icon_version'], разделы)
	
	вывод.send(разделы: разделы, запрос: ввод.данные.query)