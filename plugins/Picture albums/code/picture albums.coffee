хранилище.create_collection('picture_albums', [[[[ 'пользователь', 1 ], [ 'id', 1 ]], yes]])
хранилище.create_collection('pictures', [[[[ 'альбом', 1 ], [ 'id', 1 ]], yes]])
	
http.get '/человек/картинки/альбомы', (ввод, вывод) ->
	человек = пользовательское.взять.await({ 'адресное имя': ввод.данные['адресное имя'] })

	$ = {}

	$.пользователь = { имя: человек.имя }
	$.альбомы = db('picture_albums')._.find({ пользователь: человек._id }, { sort: [['_id', 1]] })
			
	вывод.send $
	
http.get '/человек/картинки/альбом', (ввод, вывод) ->
	человек = пользовательское.взять.await({ 'адресное имя': ввод.данные['адресное имя'] })
		
	$ = {}
		
	$.пользователь = { имя: человек.имя }
	$.альбом = db('picture_albums')._.find_one({ пользователь: человек._id, id: ввод.данные.альбом })

	if not $.альбом?
		return вывод.send(альбом: { картинки: [] })
	
	$.альбом.картинки = db('pictures')._.find({ альбом: $.альбом._id }, { sort: [['_id', 1]] })
			
	вывод.send $