http.get '/читальня/раздел или заметка/найти', (ввод, вывод) ->
	if not ввод.настройки.название?
		return вывод.send(ошибка: yes)
		
	шаблон = new RegExp('^' + RegExp.escape(ввод.настройки.название))
	
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_categories').ensureIndex 'название', no, @
		.сделать ->
			хранилище.collection('library_articles').ensureIndex 'название', no, @
		.сделать ->
			хранилище.collection('library_categories').find({ название: шаблон }, { limit: ввод.настройки.сколько }).toArray @._.в 'разделы'
		.сделать ->
			Object.выбрать(['_id', 'id', 'название'], @._.разделы)
			if (@._.разделы.length == ввод.настройки.сколько)
				return вывод.send(разделы: @._.разделы)
			хранилище.collection('library_articles').find({ название: шаблон }, { limit: ввод.настройки.сколько }).toArray @._.в 'заметки'
		.сделать ->
			Object.выбрать(['_id', 'id', 'название'], @._.заметки)
			вывод.send(разделы: @._.разделы, заметки: @._.заметки)

http.get '/читальня/раздел', (ввод, вывод) ->
	_id = ввод.настройки._id

	цепь(вывод)
		.сделать ->
			if not _id?
				@.$.раздел = {}
				return @.done()
			хранилище.collection('library_categories').findOne({ _id: хранилище.collection('library_categories').id(_id) }, @.в 'раздел')
			
		.сделать ->
			if not @.$.раздел?
				return @.error("Раздел не найден")
				
			@.$.раздел.подразделы = []
			@.$.раздел.заметки = []
			
			if not _id?
				# мы находимся на главной странице читальни
				хранилище.collection('library_categories').find(надраздел: { $exists: 0 }).toArray @
			else
				# мы находимся на странице некоего раздела читальни
				хранилище.collection('library_categories').find(надраздел: @.$.раздел._id).toArray @
		
		.каждый (подраздел) ->
			@.$.раздел.подразделы.push(подраздел)
			хранилище.collection('library_paths').findOne({ раздел: подраздел._id }, @)
		
		.сделать (пути_к_подразделам) ->
			for путь in пути_к_подразделам
				for подраздел in @.$.раздел.подразделы
					if подраздел._id + '' == путь.раздел + ''
						подраздел.путь = путь.путь

			@.done()
				
		.сделать ->
			if not _id?
				# мы находимся на главной странице читальни
				хранилище.collection('library_articles').find(раздел: { $exists: 0 }).toArray @
			else
				# мы находимся на странице некоего раздела читальни
				хранилище.collection('library_articles').find(раздел: @.$.раздел._id).toArray @
		
		.каждый (заметка) ->
			@.$.раздел.заметки.push(заметка)
			хранилище.collection('library_paths').findOne({ заметка: заметка._id }, @)
		
		.сделать (пути_к_заметкам) ->
			for путь in пути_к_заметкам
				for заметка in @.$.раздел.заметки
					if заметка._id + '' == путь.заметка + ''
						заметка.путь = путь.путь

			@.done()

		.сделать () ->
			вывод.send(@.$)

http.get "/читальня/заметка", (ввод, вывод) ->
	_id = ввод.настройки._id

	цепь(вывод)
		.сделать ->
			if not _id?
				return @.error()
			хранилище.collection('library_articles').findOne({ _id: хранилище.collection('library_articles').id(_id) }, @)
			
		.сделать (заметка) ->
			if not заметка?
				return @.error("Заметка не найдена")
			вывод.send(заметка: заметка)
			
http.get "/раздел или заметка?", (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_paths').findOne({ путь: ввод.настройки.путь }, @)
			
		.сделать (раздел_или_заметка) ->
			if not раздел_или_заметка?
				return @.error("Раздел или заметка «#{ввод.настройки.путь}» не найдены", { уровень: 'ничего страшного' })
			if раздел_или_заметка.заметка?
				return вывод.send(заметка: раздел_или_заметка.заметка)
			else
				return вывод.send(раздел: раздел_или_заметка.раздел)
				
http.post "/получить_право_на_правку_заметки", (ввод, вывод) ->
	return if пользовательское.требуется_вход(ввод, вывод)
	console.log(123)
	_id = хранилище.collection('library_articles').id(ввод.body._id)
	
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if not заметка?
				return @.error "Заметка № #{_id} не найдена"
			if заметка['кто правит']?
				if заметка['кто правит'].toString() == ввод.session.пользователь._id.toString()
					return вывод.send {}
				return new Цепочка(@)
					.сделать ->
						пользовательское.взять(заметка['кто правит'], @)
					.сделать (человек) ->
						вывод.send { 'кто правит': человек }
			хранилище.collection('library_articles').update({ _id: _id }, { $set: { 'кто правит': ввод.session.пользователь._id }}, @)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if заметка['кто правит'].toString() != ввод.session.пользователь._id.toString()
				return @.error("Не удалось занять право на правку заметки")
			вывод.send {}
			
http.put '/читальня/заметка', (ввод, вывод) ->
	return if пользовательское.требуется_вход(ввод, вывод)
	_id = хранилище.collection('library_articles').id(ввод.body._id)
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if not заметка?
				return @.error "Заметка № #{_id} не найдена"
			if not заметка['кто правит']?
				return @.error "Право на правку заметки № #{_id} не выдано"
			if заметка['кто правит'].toString() != ввод.session.пользователь._id.toString()
				return @.error "Право на правку заметки № #{_id} принадлежит другому человеку"
			хранилище.collection('library_articles').update({ _id: _id }, { $set: { название: ввод.body.title, содержимое: ввод.body.content }, $unset: { 'кто правит': 1 }}, @)
		.сделать (заметка) ->
			вывод.send {}
			
http['delete'] '/черновик', (ввод, вывод) ->
	return if пользовательское.требуется_вход(ввод, вывод)
	
	if ввод.body.что != 'заметка'
		return вывод.send ошибка: "это не заметка"
	
	_id = хранилище.collection('library_articles').id(ввод.body._id)
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @.в 'заметка')
		.сделать (заметка) ->
			if not заметка?
				return @.error "Заметка № #{_id} не найдена"
			if not заметка['кто правит']?
				return @.error "Право на правку заметки № #{_id} не выдано"
			if заметка['кто правит'].toString() != ввод.session.пользователь._id.toString()
				return @.error "Право на правку заметки № #{_id} принадлежит другому человеку"
			хранилище.collection('library_articles').update({ _id: _id }, { $unset: { 'кто правит': 1 }}, @)
		.сделать (заметка) ->
			хранилище.collection('library_article_drafts').remove({ '_id заметки': _id, '_id человека': ввод.session.пользователь._id }, @)
		.сделать ->
			вывод.send @.$.заметка