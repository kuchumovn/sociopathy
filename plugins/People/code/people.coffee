#хранилище.bind 'people',
#	выбрать: (настройки, возврат) ->
#		условия = настройки.условия || {}
#		@find(условия, { skip: настройки.с - 1, limit: настройки.сколько }).toArray возврат

http.get '/люди/найти', (ввод, вывод) ->
	люди = db('people')._.find({ имя: { $regex: '.*' + RegExp.escape(ввод.данные.query) + '.*', $options: 'i' } }, { limit: ввод.данные.max })
	вывод.send(люди: люди)
			
http.get '/люди', (ввод, вывод) ->
	options =
		collection: 'people'
		query: {},
		total: yes
		
	result = either_way_loading(ввод, options)
	
	for man in result.data
		man = пользовательское.скрыть(man)
		
	ответ = 
		люди: result.data
		'есть ещё?': result['есть ещё?']
		'есть ли предыдущие?': result['есть ли предыдущие?']
		всего: result.всего
		
	вывод.send(ответ)

http.get '/человек', (ввод, вывод) ->
	пользователь = null

	if ввод.данные.адресное_имя?
		пользователь = пользовательское.взять.await({ 'адресное имя': ввод.данные.адресное_имя })
	else
		пользователь = пользовательское.взять.await(ввод.данные._id)

	if not пользователь?
		ошибка =
			текст: "Пользователь «#{ввод.данные.адресное_имя}» не состоит в нашей сети"
			уровень: 'ничего страшного'
			показать: no
			
		throw ошибка
			
	$ = {}
			
	for key, value of пользователь
		$[key] = value

	session = db('people_sessions')._.find_one({ пользователь: $._id })
	$['когда был здесь'] = session['когда был здесь']
	
	картинки = db('picture_albums')._.find({ пользователь: $._id }, { limit: 1 })
	$['есть ли картинки?'] = !картинки.пусто()
			
	видеозаписи = db('video_albums')._.find({ пользователь: $._id }, { limit: 1 })
	$['есть ли видеозаписи?'] = !видеозаписи.пусто()
			
	книги = db('peoples_books')._.find_one({ пользователь: $._id })
	if книги? && !книги.книги.пусто()
		$['есть ли книги?'] = yes
			
	#.сделать ->
	#	db('diaries').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
		
	#.сделать (diaries) ->
	#	@.$['ведёт ли дневник?'] = !diaries.пусто()
		
	#.сделать ->
	#	db('journals').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
		
	#.сделать (journals) ->
	#	@.$['ведёт ли журнал?'] = !journals.пусто()

	текущий_пользователь = пользовательское.пользователь(ввод)

	if текущий_пользователь?
		круги = db('circles')._.find({ пользователь: текущий_пользователь._id })
		
		for круг in круги
			for член in круг.члены
				if член + '' == $._id + ''
					$.в_круге = круг
					break

	вывод.send $
			
http.get '/сеть/черновик', (ввод, вывод) ->
	#console.log(ввод.данные.что)
	вывод.send({})
			
http.get '/человек/по имени', (ввод, вывод) ->
	человек = db('people')._.find_one({ имя: ввод.данные.имя })
	
	if not человек?
		return вывод.send(ошибка: 'Пользователь не найден', не_найден: yes)
	
	вывод.send(пользовательское.поля(человек))
			
http.get '/человек/по почте', (ввод, вывод) ->
	человек = db('people')._.find_one({ почта: ввод.данные.почта })
	
	if not человек?
		return вывод.send(ошибка: 'Пользователь не найден', не_найден: yes)
	
	вывод.send(пользовательское.поля(человек))