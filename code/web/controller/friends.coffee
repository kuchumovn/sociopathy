http.get '/общие друзья', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			получить_данные_человека ввод.настройки.адресное_имя, вывод, @
		.сделать (человек) ->
			хранилище.collection('friends').find { пользователь: человек._id }, @
		.сделать (друзья) ->
			вывод.send друзья: друзья
