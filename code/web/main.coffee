require 'coffee-script'

mongo = require 'mongoskin'
хранилище = mongo.db 'localhost:27017/sociopathy?auto_reconnect'
global.db = хранилище

Цепочка = require './conveyor'
цепь = (вывод) -> new Цепочка('web', вывод)

пользовательское = require './user_tools'

global.application_tools = require('./express')()
http = global.application_tools.http

приложение = global.application

лекальщик = require './templater'
снасти = require './tools'
болталка = require './chat'

хранилище.bind 'people',
	выбрать: (настройки, возврат) ->
		условия = настройки.условия || {}
		@find(условия, { skip: настройки.с - 1, limit: настройки.сколько }).toArray возврат

http.put '/прописать', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			настройки =
				query:
					'ключ': ввод.body.приглашение
					
			options =
				remove: yes
			
			хранилище.collection('invites').findAndModify настройки, [], {}, options, @
			
		.сделать ->
			хранилище.collection('people').save ввод.body, @
		
		.сделать (пользователь) ->
			вывод.send ключ: пользователь._id

http.get '/люди', (ввод, вывод) ->
	цепь(вывод)
		.делать ->
			хранилище.collection('people').выбрать { с: ввод.настройки.с, сколько: ввод.настройки.сколько }, @

		.делать ->
			хранилище.collection('people').count @
		
		.сделать (люди, поголовье) ->
			есть_ли_ещё = поголовье > (ввод.настройки.с - 1 + ввод.настройки.сколько)
			вывод.send люди: люди, 'есть ещё?': есть_ли_ещё 
			
http.post '/вход', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('people').findOne { имя: ввод.body.имя }, @
		
		.сделать (пользователь) ->
			if not пользователь?
				return вывод.send ошибка: 'Такого пользователя нет в нашей сети'
		
			if пользователь.пароль != ввод.body.пароль
				return вывод.send ошибка: 'Неверный пароль'
		
			пользовательское.войти пользователь, ввод, вывод
			вывод.send пользователь: пользователь

http.post '/выход', (ввод, вывод) ->
	пользовательское.выйти ввод, вывод
	вывод.send {}
		
http.get '/приглашение/проверить', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('invites').findOne {'ключ': ввод.настройки.приглашение}, @
		
		.сделать (приглашение) ->
			if not приглашение?
				return @ 'Нет такого приглашения в списке'
				
			вывод.send приглашение: приглашение
			
http.get '/хранилище/заполнить', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('people').drop @
		
		.ошибка (ошибка) ->
			if ошибка.message == 'ns not found'
				return no
			console.error ошибка
			вывод.send ошибка: ошибка

		#.сделать ->
		#	хранилище.collection('people').ensureIndex 'пароль', true, @

		.сделать ->
			хранилище.collection('people').ensureIndex 'почта', true, @

		.сделать ->
			хранилище.collection('people').ensureIndex 'имя', true, @

		.сделать ->
			хранилище.collection('people').ensureIndex 'адресное имя', true, @

		.сделать ->
			люди = []
			for i in [1..21]
				человек = 
					имя: 'Иванов Иван ' + i
					'адресное имя': 'Иванов Иван ' + i
					описание: 'заведующий'
					пол: 'мужской'
					откуда: 'Москва'
					пароль: '' + (i + 122)
					почта: 'ivan' + i + '@ivanov.com'
					'время рождения': '12.09.1990'
					вера: 'христианин'
					убеждения: 'социалист' 
					картинка: '/картинки/temporary/картинка с личной карточки.jpg'
					
				люди.push человек
			@ null, люди
		
		.все_вместе (человек) ->
			хранилище.collection('people').save человек, @
		
		.сделать ->
			хранилище.collection('invites').drop @
		
		.ошибка (ошибка) ->
			if ошибка.message == 'ns not found'
				return no
			console.error ошибка
			вывод.send ошибка: ошибка
		
		.сделать ->
			хранилище.collection('invites').ensureIndex 'ключ', true, @
		
		.сделать ->
			хранилище.collection('invites').save { ключ: 'проверка' }, @
		
		.сделать ->
			хранилище.collection('chat').drop @
		
		.ошибка (ошибка) ->
			if ошибка.message == 'ns not found'
				return no
			console.error ошибка
			вывод.send ошибка: ошибка
				
		.сделать ->
			хранилище.createCollection 'chat', { capped: true, size: 100 }, @
				
		.сделать ->
			хранилище.collection('people').выбрать { с: 1, сколько: 2 }, @

		.делать (два_человека) ->
			хранилище.collection('chat').save { отправитель: два_человека[0]._id, сообщение: 'Ицхак (Ицик) Виттенберг родился в Вильно в 1907 году в семье рабочего. Был членом подпольной коммунистической партии в Литве, после присоединения Литвы к СССР руководил профсоюзом. После оккупации Литвы немецкими войсками перешёл на нелегальное положение.', время: '24.10.2011 16:45' }, @
				
		.делать (два_человека) ->
			хранилище.collection('chat').save { отправитель: два_человека[0]._id, сообщение: 'Dickinsonia (рус. дикинсония) — одно из наиболее характерных ископаемых животных эдиакарской (вендской) биоты. Как правило, представляет собой двусторонне-симметричное рифлёное овальное тело. Родственные связи организма в настоящее время неизвестны. Большинство исследователей относят дикинсоний к животным, однако существуют мнения, что они являются грибами или относятся к особому не существующему ныне царству живой природы.', время: '24.10.2011 16:46' }, @
				
		.делать (два_человека) ->
			хранилище.collection('chat').save { отправитель: два_человека[1]._id, сообщение: 'Овинище — Весьегонск — тупиковая однопутная 42-километровая железнодорожная линия, относящаяся к Октябрьской железной дороге, проходящая по территории Весьегонского района Тверской области (Россия) от путевого поста Овинище II, расположенного на железнодорожной линии Москва — Сонково — Мга — Санкт-Петербург (которая на разных участках называется Савёловским радиусом и Мологским ходом), до тупиковой станции Весьегонск и обеспечивающая связь расположенного на северо-восточной окраине Тверской области города Весьегонска с железнодорожной сетью страны.', время: '27.10.2011 10:20' }, @
				
		.сделать ->
			вывод.send {}
			
страницы =
[
	'physics',
	'люди',
	'прописка',
	'сеть/настройки',
	'сеть/болталка',
	'сеть/обсуждения',
	'сеть/беседы',
	'сеть/почта',
	'обложка',
	'помощь',
	'помощь/режимы',
	'заметка',
	'читальня',
	'управление'
]

страницы.forEach (страница) ->
	http.get "/страница/#{страница}", (ввод, вывод) ->
		цепь(вывод)
			.сделать ->
				лекальщик.собрать_и_отдать_страницу страница, {}, ввод, вывод

http.get "/страница/люди/:address_name", (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			хранилище.collection('people').findOne { 'адресное имя': ввод.params.address_name }, @

		.сделать (пользователь) ->
			данные = {}
			
			if not пользователь?
				данные.ошибка = "Пользователь «#{ввод.params.address_name}» не состоит в нашей сети"
				console.error данные.ошибка
			else
				данные.данные_пользователя =
					имя: пользователь.имя
					описание: пользователь.описание
					картинка: пользователь.картинка
					пол: пользователь.пол
					откуда: пользователь.откуда
					
				данные.данные_пользователя = JSON.stringify данные.данные_пользователя
				
			лекальщик.собрать_и_отдать_страницу 'человек', данные, ввод, вывод
			
приложение.listen 8080, '0.0.0.0'