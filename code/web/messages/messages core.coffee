#require 'coffee-trace'

global.prepare_messages = (options) ->
	options.collection = options.id

	options.these_messages_query = (query, environment) ->
		if not options.messages_query?
			return query
		
		Object.merge_recursive(Object.clone(query), options.messages_query(environment))
		
	if options.общение_во_множественном_числе?
		options.messages_collection = 'messages'
		options.path = (environment) -> options.общение_во_множественном_числе + '.' + environment.сообщения_чего._id
			
		options.messages_query = (environment) ->
			query = {}
			query.чего = options.общение
			if environment.сообщения_чего._id.toHexString?
				query.общение = environment.сообщения_чего._id
			else
				query.общение = collection.id(environment.сообщения_чего._id)
			query
			
		options.notified_users = (общение) ->
			if общение.подписчики?
				return общение.подписчики
			return []
		
		http.get '/сеть/' + options.общение_во_множественном_числе, (ввод, вывод, пользователь) ->
			if not options.общения_query?
				options.общения_query = () -> {}

			общения = снасти.batch_loading.await(ввод, { from: options.collection, query: options.общения_query(пользователь), parameters: { sort: [['обновлено', -1]] } })
			
			пользовательское.подставить.await(общения, 'участники')
			
			if options.bulk_get_extra?
				options.bulk_get_extra(общения)
		
			последние_сообщения = []
		
			for общение in общения
				последние_сообщения.push(db(options.messages_collection)._.find({ общение: общение._id, чего: options.общение }, { sort: [['_id', -1]], limit: 1 }))
				
			сообщения = []
			for array in последние_сообщения
				if not array.пусто()
					сообщения.push(array[0])
			
			последние_сообщения = сообщения
			последние_сообщения = пользовательское.подставить.await(последние_сообщения, 'отправитель')
			
			последние_сообщения.merge_into(общения, 'последнее_сообщение', (общение) -> @.общение + '' == общение._id + '')
					
			$ = {}
			$[options.общение_во_множественном_числе] = общения
					
			вывод.send $
			
	else
		options.messages_collection = options.id
		options.path = (environment) -> options.общение
		
	options.uri = '/' + options.общение
	options.data_uri = '/сеть/' + options.общение + '/сообщения'

	save = options.save
	options.save = (сообщение, environment, возврат) ->
		data =
			отправитель: environment.пользователь._id
			сообщение: сообщение
			когда: new Date()
			
		if options.общение_во_множественном_числе?
			data.общение = environment.сообщения_чего._id
			data.чего = options.общение
				
		сообщение = db(options.messages_collection)._.save(data)
				
		if options.общение_во_множественном_числе?
			db(options.collection)._.update({ _id: environment.сообщения_чего._id }, { $set: { обновлено: data.когда } })

		if save?
			save(сообщение, environment)
		
		возврат(null, сообщение)
	
	if options.общение_во_множественном_числе?
		options.сообщения_чего_from_string = (сообщения_чего) ->
			if сообщения_чего._id.toHexString?
				return сообщения_чего
			сообщения_чего._id = db(options.collection).id(сообщения_чего._id)
			return сообщения_чего
		
		options.создатель = (_id, возврат) ->
			if typeof _id == 'string'
				_id = db(options.id).id(_id)
			
			сообщения = db(options.messages_collection)._.find({ общение: _id, чего: options.общение }, { sort: [['_id', 1]], limit: 1 })
					
			if сообщения.пусто()
				throw "Не удалось проверить авторство"
						
			возврат(null, сообщения[0].отправитель)

		if options.private?
			options.notified_users = (общение) -> общение.участники
				
			options.authorize = (environment, возврат) ->
				общение = хранилище.collection(options.collection)._.find_one({ _id: environment.сообщения_чего._id })
						
				if not общение.участники?
					throw { error: 'Вы не участвуете в этом общении', display_this_error: yes }
				
				if not общение.участники.map((_id) -> _id + '').has(environment.пользователь._id + '')
					throw { error: 'Вы не участвуете в этом общении', display_this_error: yes }
				
				возврат()
						
			options.добавить_в_общение = (_id, добавляемый, пользователь, возврат) ->
				общение = db(options.collection)._.find_one({ _id: _id })
						
				нет_прав = yes
			
				if общение.участники?
					for участник in общение.участники
						if участник + '' == добавляемый + ''
							return возврат(null, { уже_участвует: yes })
						if участник + '' == пользователь._id + ''
							нет_прав = no
							
				if нет_прав
					throw "Вы не участник этого общения, и поэтому \n не можете добавлять в неё людей"
	
				db(options.collection)._.update({ _id: _id }, { $addToSet: { участники: добавляемый } })
				
				session = db('people_sessions')._.find_one({ пользователь: добавляемый })
				
				query = { чего: options.общение, общение: _id }
					
				latest_messages = db(options.messages_collection)._.find(query, { limit: 1, sort: [['_id', -1]] })
		
				latest_message_id = latest_messages.map((message) -> message._id.toString())[0]
				
				has_new_messages = yes
				
				latest_read = options.latest_read(session, { сообщения_чего: { _id: _id } })
				if latest_read?
					if latest_read + '' == latest_message_id + ''
						has_new_messages = no
					
				эфир.отправить('новости', options.общение + '.' + 'добавление', { id: общение.id, название: общение.название }, { кому: добавляемый })
					
				if has_new_messages?
					эфир.отправить('новости', options.общение, { _id: _id.toString(), сообщение: latest_message_id }, { кому: добавляемый })
					
					set_id = 'новости.' + options.path({ сообщения_чего: { _id: _id } })
					
					set_operation = {}
					set_operation[set_id] = latest_message_id
					
					db('people_sessions')._.update({ пользователь: добавляемый }, { $set: set_operation })
				else
					эфир.отправить.await('новости', options.общение + '.' + 'добавление', { id: общение.id, название: общение.название }, { кому: добавляемый })
					
				возврат()
					
			options.creation_extra = (_id, пользователь, ввод, возврат) ->
				кому = ввод.body.кому
				
				if not кому?
					return возврат()
				
				options.добавить_в_общение.await(_id, db('people').id(кому), пользователь)
				возврат()

		options.сообщения_чего = (ввод, возврат) ->
			сообщения_чего = null
		
			if ввод.настройки._id?
				сообщения_чего = db(options.collection)._.find_one({ _id: ввод.настройки._id })
			else
				сообщения_чего = db(options.collection)._.find_one({ id: ввод.настройки.id })
	
			result = Object.выбрать(['_id', 'название'], сообщения_чего)
			if options.сообщения_чего_extra?
				options.сообщения_чего_extra(result, сообщения_чего)
			
			возврат(null, result)
					
		extra_get = (data, environment, возврат) ->
			if options.private?
				data.участники = environment.сообщения_чего.участники
			возврат()
					
		options.extra_get = (data, environment, возврат) ->
			data.название = environment.сообщения_чего.название
			data._id = environment.сообщения_чего._id
			
			if extra_get?
				extra_get.await(data, environment)
				
			возврат()
					
	options.latest_read = (session, environment) ->
		return Object.path(session, 'последние_прочитанные_сообщения.' + options.path(environment))

	options.message_read = (_id, environment, возврат) ->
		path = 'последние_прочитанные_сообщения.' + options.path(environment)

		query = { пользователь: environment.пользователь._id }
		
		query.$or = []
			
		query.$or.push({ последние_прочитанные_сообщения: { $exists: 0 } })
		
		less_than = {}
		less_than[path] = { $lt: _id }
		
		nothing_read_yet = {}
		nothing_read_yet[path] = { $exists: 0 }
		
		query.$or.push(less_than)
		query.$or.push(nothing_read_yet)
			
		actions = $set: {}
		actions.$set[path] = _id
		
		db('people_sessions')._.update(query, actions)
		
		возврат()
				
	options.notify = (сообщение, environment, возврат) ->
		_id = сообщение._id

		users = []
	
		if options.общение_во_множественном_числе?
			общение = db(options.collection)._.find_one({ _id: environment.сообщения_чего._id })
			
			query = {}
			
			query.$or = []
						   
			subquery = {}
			subquery['последние_сообщения.' + options.path(environment)] = { $exists: 0 }
			query.$or.push(subquery)
			
			subquery = {}
			subquery['последние_сообщения.' + options.path(environment)] = { $lt: _id }
			query.$or.push(subquery)
			
			if options.notified_users?
				users = options.notified_users(общение)
				query.пользователь = { $in: users }
			
			setter = {}
			setter['последние_сообщения.' + options.path(environment)] = _id
			
			db('people_sessions').update(query, { $set: setter }, { multi: yes })
			
			users = users.map((_id) -> _id.toString())
		else
			if not options.info_collection?
				options.info_collection = options.collection + '_info'
			
			query = {}
			
			query.$or = []
			query.$or.push({ последнее_сообщение: { $exists: 0 } })
			query.$or.push({ последнее_сообщение: { $lt: _id } })
			
			db(options.info_collection)._.update(query, { $set: { последнее_сообщение: _id } })
		
		data =
			сообщение: _id.toString()
			text: сообщение.сообщение

		if environment.сообщения_чего?
			data._id = environment.сообщения_чего._id.toString()
			общение = db(options.collection)._.find_one({ _id: environment.сообщения_чего._id })
			data.id = общение.id
			data.отправитель = environment.пользователь
		
		if not users.пусто()
			for user in users
				if user != environment.пользователь._id.toString()
					эфир.отправить('новости', options.общение, data, { кому: user })
		else
			эфир.отправить('новости', options.общение, data, { кроме: environment.пользователь._id })

		for пользователь in эфир.пользователи()
			if пользователь != environment.пользователь._id + ''
				if !users.пусто() && !users.has(пользователь)
					continue
				
				criteria = { пользователь: пользователь }
				if environment.сообщения_чего?
					criteria._id = environment.сообщения_чего._id.toString()
					
				соединение_с_общением = эфир.соединение_с(options.общение, criteria)
				if not соединение_с_общением
					эфир.отправить_одному_соединению('новости', 'звуковое оповещение', { чего: options.общение }, { кому: пользователь })
					
		возврат()

	options.mark_new = (сообщения, environment, возврат) ->
		session = db('people_sessions')._.find_one({ пользователь: environment.пользователь._id })
		
		path = 'последние_прочитанные_сообщения.' + options.path(environment)
		latest_read = Object.path(session, path)
		
		if not latest_read?
			for сообщение in сообщения
				сообщение.новое = yes
			return @.return()
			
		for сообщение in сообщения
			if сообщение._id + '' > latest_read + ''
				сообщение.новое = yes
		
		возврат()