http.get '/дневник', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			получить_данные_человека ввод.настройки.адресное_имя, вывод, @
		.сделать (человек) ->
			хранилище.collection('blogs').findOne { сочинитель: человек._id }, @
		.сделать (дневник) ->
			вывод.send дневник
