http.get '/заметка', (ввод, вывод) ->
	снасти.получить_данные_человека ввод.настройки.address_name, вывод, (данные) ->
		вывод.send данные: данные
		
получить_данные_раздела = (путь, вывод, возврат) ->
	new Цепочка()
		.сделать ->
			if путь?
				хранилище.collection('library_categories').findOne { путь: путь }, @.в 'раздел'
			else
				(@.в 'раздел')(null, {})

		.сделать (раздел) ->
			if not раздел?
				return вывод.send
					ошибка:
						текст: "Раздел читальни или заметка «#{путь}» не найдены"
						уровень: 'ничего страшного'
				
			раздел.подразделы = []
			раздел.заметки = []
			@ null, раздел

		.сделать (раздел) ->
			if раздел._id?
				хранилище.collection('library_categories').find(надраздел: раздел._id).toArray @
			else
				хранилище.collection('library_categories').find(надраздел: { '$exists': 0 }).toArray @
		
		.каждый (подраздел) ->
			раздел = @.переменная 'раздел'
			раздел.подразделы.push подраздел
			@()

		.сделать (раздел) ->
			раздел = @.переменная 'раздел'
		
			if раздел._id?
				хранилище.collection('library_articles').find(раздел: раздел._id).toArray @
			else
				хранилище.collection('library_articles').find(раздел: { '$exists': 0 }).toArray @
		
		.каждый (заметка) ->
			раздел = @.переменная 'раздел'
			раздел.заметки.push заметка
			@()

		.сделать (раздел) ->
			раздел = @.переменная 'раздел'
			возврат null, раздел
			
		.ошибка (ошибка) ->
			возврат ошибка

http.get '/раздел читальни', (ввод, вывод) ->
	путь = ввод.настройки.путь
	
	цепь(вывод)
		.сделать ->
			получить_данные_раздела(путь, вывод, @)
			
		.сделать (данные) ->
			вывод.send данные

http.get "/раздел или заметка?", (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ путь: ввод.настройки.путь }, @)
			
		.сделать (заметка) ->
			if заметка?
				return вывод.send(заметка: заметка)
			else
				return вывод.send(раздел: yes)
				
http.post "/получить_право_на_правку_заметки", (ввод, вывод) ->
	return if пользовательское.требуется_вход(ввод, вывод)
	_id = хранилище.collection('library_articles').id(ввод.body._id)
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if not заметка?
				@.error "Заметка № #{_id} не найдена"
			if заметка['кто правит']?
				if заметка['кто правит'].toString() == ввод.session.пользователь._id.toString()
					return вывод.send {}
				return new Цепочка(@)
					.сделать ->
						хранилище.collection('people').findOne({ _id: заметка['кто правит'] }, @)
					.сделать (человек) ->
						вывод.send { 'кто правит': человек }
			хранилище.collection('library_articles').update({ _id: _id }, { $set: { 'кто правит': ввод.session.пользователь._id }}, @)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if заметка['кто правит'].toString() != ввод.session.пользователь._id.toString()
				return @.error("Не удалось занять право на правку заметки")
			вывод.send {}
			
http.post '/заметка/сохранить', (ввод, вывод) ->
	return if пользовательское.требуется_вход(ввод, вывод)
	_id = хранилище.collection('library_articles').id(ввод.body._id)
	цепь(вывод)
		.сделать ->
			хранилище.collection('library_articles').findOne({ _id: _id }, @)
		.сделать (заметка) ->
			if not заметка?
				@.error "Заметка № #{_id} не найдена"
			if not заметка['кто правит']?
				@.error "Право на правку заметки № #{_id} не выдано"
			if заметка['кто правит'].toString() != ввод.session.пользователь._id.toString()
				@.error "Право на правку заметки № #{_id} принадлежит другому человеку"
			хранилище.collection('library_articles').update({ _id: _id }, { $set: { название: ввод.body.title, содержимое: ввод.body.content }, $unset: { 'кто правит': 1 }}, @)
		.сделать (заметка) ->
			вывод.send {}