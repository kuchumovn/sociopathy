# защита от перебора пароля:
#
# когда вход, проверяют "предыдущую неудавшуюся попытку входа"
# если она меньше, чем за час до текущей - ставить "температуру" в 2 раза больше (2, если ноль), и прописывать уже эту дату попытки входа
# если температура больше 1000 - не давать входить.
# каждые 15 минут температура остывает в 2 раза
http.post '/вход', (ввод, вывод) ->
	The_hottest_allowed_temperature = 1000
	Temperature_half_life = 15 # minutes
	Temperature_doubles_when_in_interval = 60 # minutes
	
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ имя: ввод.body.имя }, { полностью: yes }, @._.в 'пользователь')
		
		.сделать (пользователь) ->
			if not пользователь?
				return вывод.send ошибка: 'Такого пользователя нет в нашей сети'
		
			db('people_sessions').findOne({ пользователь: пользователь._id }, @._.в 'session')
			
		.сделать ->
			# насколько успело остыть - настолько остудить
			@._.температура = 0
			if @._.session.последний_неудавшийся_вход?
				@._.температура = @._.session.последний_неудавшийся_вход.температура
				когда = @._.session.последний_неудавшийся_вход.когда
				сейчас = new Date()
				
				while когда.add(Temperature_half_life).minutes().isBefore(сейчас)
					@._.температура /= 2
					когда = когда.add(Temperature_half_life).minutes()
					if @._.температура < 1
						@._.температура = 0
						delete @._.session.последний_неудавшийся_вход
						break
					
			@.done()

		.сделать ->
			if @._.пользователь.пароль != ввод.body.пароль
				@._.не_вошёл = yes
				if @._.температура < The_hottest_allowed_temperature
					if @._.session.последний_неудавшийся_вход?
						if @._.session.последний_неудавшийся_вход.когда.add(Temperature_doubles_when_in_interval).minutes().isAfter(new Date())
								@._.температура *= 2
					else
						@._.температура = 2
						
					return db('people_sessions').update({ пользователь: @._.пользователь._id }, { $set: { последний_неудавшийся_вход: { когда: new Date(), температура: @._.температура } } }, @)
			
			@.done()

		.сделать ->
			if @._.температура >= The_hottest_allowed_temperature
				return вывод.send ошибка: 'Возможно вы пытаетесь взломать пароль. Попробуйте позже.'
				
			if @._.не_вошёл?
				return вывод.send ошибка: 'Неверный пароль'
			
			db('people_sessions').update({ пользователь: @._.пользователь._id }, { $unset: { последний_неудавшийся_вход: yes } }, @)
			
		.сделать ->
			пользовательское.войти(@._.пользователь, ввод, вывод, @)
		
		.сделать ->
			вывод.send(пользователь: пользовательское.поля(@._.пользователь))

http.post '/выход', (ввод, вывод) ->
	пользовательское.выйти ввод, вывод
	вывод.send {}
	
http.put '/прописать', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			if not Options.Invites
				return @.done()
			
			цепь(@)
				.сделать ->
					query =
						ключ: ввод.body.приглашение,
						использовано:  { $exists : no } 
							
					update = { $set: { использовано: yes } }
					
					db('invites').findAndModify(query, [], update, {}, @)

				.сделать (invite) ->
					if not invite?
						throw 'No invite given'
					return @.done()
			
		.сделать ->
			@._.человек = ввод.body
			
			@._.человек['когда пришёл'] = new Date()
			
			проверка = (id, возврат) ->
				цепь(возврат)
					.сделать ->
						db('people').findOne({ id: id }, @)
					
					.сделать (found) ->
						@.done(not found?)
						
			снасти.generate_unique_id(@._.человек.имя, проверка, @)
			
		.сделать (адресное_имя) ->
			@._.человек['адресное имя'] = адресное_имя
					
			#@._.человек.почта = @._.человек.имя + '@sobranie.net'
			
		#	снасти.hash(@._.человек.пароль, @)
			
		#.сделать (hash) ->
		#	@._.человек.пароль = hash
		
			db('people').save(@._.человек, @._.в 'пользователь')
	
		.сделать (пользователь) ->
			@.done(пользовательское.сделать_тайный_ключ(пользователь))
			
		.сделать (тайный_ключ) ->
			db('people_private_keys').save({ пользователь: @._.пользователь._id, 'тайный ключ': тайный_ключ }, @)

		.сделать ->
			db('circles').save({ пользователь: @._.человек._id, круг: 'Основной', члены: [] }, @)

		.сделать ->
			db('people_sessions').save({ пользователь: @._.человек._id }, { новости: { беседы: {}, обсуждения: {}, новости: [] }}, @)

		.сделать ->
			db('news').save({ что: 'прописка', пользователь: @._.человек._id, когда: new Date() }, @)
			
		.сделать ->
			вывод.send(ключ: @._.пользователь._id)

http.get '/приглашение/проверить', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			db('invites').findOne {ключ: ввод.настройки.приглашение.toString() }, @
		
		.сделать (приглашение) ->
			if not приглашение?
				return @.error('Нет такого приглашения в списке')
				
			if приглашение.использовано
				return @.error('Это приглашение уже использовано')
				
			вывод.send приглашение: приглашение

http.get '/пользовательские_данные_для_страницы', (ввод, вывод) ->
	if ввод.session?
		цепь(вывод)
			.сделать ->
				пользовательское.пользователь(ввод, @.в 'пользователь')
				
			.сделать ->
				db('people_sessions').findOne({ пользователь: @.$.пользователь._id }, @)
				
			.сделать (session) ->
				@.$.session =
					настройки: session.настройки
					не_показывать_подсказки: session.не_показывать_подсказки
				
				@.$.пользователь = пользовательское.поля(['...', 'photo_version', 'полномочия'], @.$.пользователь)
				@.$.пользователь.беседы = {}
				@.$.пользователь.обсуждения = {}
				@.$.пользователь.новости = {}
				
				вывод.send(@.$)
				
	else
		if ввод.cookies.user?
			вывод.clearCookie 'user'
		вывод.send(ошибка: 'Пользователь не найден')
		
http.put '/сеть/человек/данные', (ввод, вывод, пользователь) ->
	цепь(вывод)
		.сделать ->
			if ввод.body.имя != пользователь.имя
				return db('people').findOne({ имя: ввод.body.имя, _id: { $ne: пользователь._id } }, @)
			@.done()
			
		.сделать (человек_с_таким_именем) ->
			if человек_с_таким_именем?
				show_error('Такое имя уже занято')
				
			# проверка на занятость имени не атомарна, но пока так сойдёт
			db('people').update({ _id: пользователь._id }, { $set: { имя: ввод.body.имя, описание: ввод.body.описание, откуда: ввод.body.откуда, 'о себе': JSON.parse(ввод.body.о_себе) } }, @)
			
		.сделать ->
			вывод.send {}
			
			if (ввод.body.имя != пользователь.имя)
				эфир.отправить('пользователь', 'смена имени', ввод.body.имя, { кому: пользователь._id })
			
http.put '/сеть/человек/картинка', (ввод, вывод, пользователь) ->
	имя = ввод.body.имя.to_unix_file_name()
	
	путь = Options.Upload_server.Temporary_file_path + '/' + имя + '.jpg'
	место = null

	цепь(вывод)
		.сделать ->
			место = Options.Upload_server.File_path + '/люди/' + пользователь['адресное имя'].to_unix_file_name() + '/картинка'
			снасти.создать_путь(место, @)
			
		.сделать ->			
			resize(путь, место + '/маленькая.jpg', { размер: Options.User.Picture.Chat.Size, квадрат: yes }, @)
			
		.сделать ->
			снасти.переместить_и_переименовать(путь, { место: место, имя: 'большая.jpg' }, @)
			
		.сделать ->
			db('people').update({ _id: пользователь._id }, { $inc: { 'avatar_version': 1 } }, { safe: yes }, @)
			
		.сделать ->
			db('people').findOne({ _id: пользователь._id }, @)
			
		.сделать (пользователь) ->
			эфир.отправить('пользователь', 'аватар обновлён', { version: пользователь.avatar_version }, { кому: пользователь._id })
			вывод.send {}

http.put '/сеть/человек/фотография', (ввод, вывод, пользователь) ->
	имя = ввод.body.имя.to_unix_file_name()
	
	путь = Options.Upload_server.Temporary_file_path + '/' + имя + '.jpg'
	место = null

	цепь(вывод)
		.сделать ->
			место = Options.Upload_server.File_path + '/люди/' + пользователь['адресное имя'].to_unix_file_name()
			снасти.создать_путь(место, @)
			
		.сделать ->
			снасти.переместить_и_переименовать(путь, { место: место, имя: 'фотография.jpg' }, @)
			
		.сделать ->
			db('people').update({ _id: пользователь._id }, { $inc: { 'photo_version': 1 } }, { safe: yes }, @)
			
		.сделать ->
			вывод.send {}

http.get '/сеть/пользователь/настройки', (ввод, вывод, пользователь) ->
	цепь(вывод)
		.сделать ->
			пользовательское.пользователь_полностью(ввод, @._.в 'пользователь')
			
		.сделать ->
			db('people_sessions').findOne({ пользователь: пользователь._id }, @._.в 'session')
			
		.сделать (пользователь) ->
			настройки = {}
			
			if (пользователь.почта)
				настройки.почта = пользователь.почта
			
			if пользователь.настройки
				настройки.настройки = пользователь.настройки
				
			настройки.язык = @._.session.настройки.язык
				
			#настройки.Клавиши = @._.session.настройки.Клавиши
				
			вывод.send настройки

http.post '/сеть/пользователь/настройки', (ввод, вывод, пользователь) ->
	клавиши = JSON.parse(ввод.body.клавиши)
	
	цепь(вывод)
		.сделать ->
			пользовательское.пользователь_полностью(ввод, @._.в 'пользователь')
			
		.сделать (пользователь) ->
			@._.почта_изменилась = (пользователь.почта != ввод.body.почта)
			
			if @._.почта_изменилась
				return db('people').findOne({ почта: ввод.body.почта, _id: { $ne: пользователь._id } }, @)
			@.done()
			
		.сделать (человек_с_такой_почтой) ->
			if человек_с_такой_почтой?
				show_error('Вы указали почтовый ящик, уже записанный на другого члена нашей сети')
				
			# проверка на занятость имени не атомарна, но пока так сойдёт
			
			@._.новые_данные_пользователя = {}
			
			if (ввод.body.почта)
				@._.новые_данные_пользователя.почта = ввод.body.почта
				
			db('people').update({ _id: пользователь._id }, { $set: @._.новые_данные_пользователя }, @)
			
		.сделать ->
			настройки = {}
			
			настройки.клавиши = клавиши
				
			if ввод.body.язык?
				настройки.язык = ввод.body.язык
			
			db('people_sessions').update({ пользователь: пользователь._id }, { $set: { настройки: настройки } }, @)
			
		.сделать ->
			if @._.почта_изменилась
				почта.письмо(кому: пользователь.имя + ' <' + @._.пользователь.почта + '>', тема: 'Проверка вашего нового почтового ящика', сообщение: 'Теперь это ваш почтовый ящик в нашей сети')
				
			эфир.отправить("пользователь", "настройки.клавиши", { клавиши: клавиши }, { кому: пользователь._id })
				
			вывод.send {}

http.get '/сеть/мусорка/личная', (ввод, вывод, пользователь) ->
	цепь(вывод)
		.сделать ->
			db('trash').find({ пользователь: пользователь._id }).toArray(@)
			
		.сделать (содержимое) ->
			вывод.send { содержимое: содержимое }
			
http.delete '/сеть/подсказка', (ввод, вывод, пользователь) ->
	цепь(вывод)
		.сделать ->
			db('people_sessions').update({ пользователь: пользователь._id }, { $addToSet: { 'не_показывать_подсказки': ввод.body.подсказка } }, @)
			
		.сделать (session) ->
			эфир.отправить("пользователь", "не_показывать_подсказку", { подсказка: ввод.body.подсказка }, { кому: пользователь._id })
			вывод.send {}
			
http.get '/сеть/черновик', (ввод, вывод, пользователь) ->
	что = ввод.настройки.что
	
	цепь(вывод)
		.сделать ->
			query = null
			
			if что == 'заметка'
				query = { заметка: ввод.настройки.заметка }
			else
				query = { что: что }
				
			db('drafts').findOne(Object.x_over_y({ пользователь: пользователь._id }, query), @)
			
		.сделать (черновик) ->
			if not черновик?
				return вывод.send({})
			вывод.send(черновик: черновик.данные)
			
http.put '/сеть/черновик', (ввод, вывод, пользователь) ->
	что = ввод.настройки.что
	данные = ввод.настройки.данные
	
	цепь(вывод)
		.сделать ->
			query = null
			
			if что == 'заметка'
				query = { заметка: ввод.настройки.заметка }
			else
				query = { что: что }
				
			db('drafts').update(Object.x_over_y({ пользователь: пользователь._id }, query), { $set: { данные: данные } }, @)
			
		.сделать ->
			вывод.send({})
			
http.get '/сеть/пароль', (ввод, вывод, пользователь) ->
	цепь(вывод)
		.сделать ->
			db('people').update({ _id: пользователь._id, пароль: '123' }, { $set: { пароль: ввод.настройки.пароль } }, @)
			
		.сделать ->
			вывод.send({})
