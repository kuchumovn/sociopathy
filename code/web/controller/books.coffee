http.get '/книги', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			получить_данные_человека ввод.настройки.адресное_имя, вывод, @
		.сделать (человек) ->
			хранилище.collection('books').find { пользователь: человек._id }, @
		.сделать (книги) ->
			вывод.send книги: книги
