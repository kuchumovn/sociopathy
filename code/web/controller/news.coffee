http.get '/сеть/новости', (ввод, вывод, пользователь) ->
	круг = ввод.настройки.круг
	
	цепь(вывод)
		.сделать ->
			if not круг?
				return @.done('Все')
			db('circles').findOne({ пользователь: пользователь._id, круг: круг }, @)
			
		.сделать (круг) ->
			if not круг?
				console.error("Круг #{ввод.настройки.круг} не найден")
				return вывод.send(новости: [])
				
			query = {}
			if круг != 'Все'
				query.пользователь = { $in: круг.члены }
				
			снасти.batch_loading(ввод, { from: 'news', query: query }, @.в 'новости')
			
		.сделать ->
			пользовательское.подставить(@.$.новости, 'пользователь', @)
			
		.сделать ->
			вывод.send @.$
			
exports.уведомления = (пользователь, возврат) ->
	цепь(возврат, { manual: yes })
		.сделать ->
			db('people_sessions').findOne({ пользователь: пользователь._id }, @._.в 'session')
			
		#.сделать ->
		#	db('circles').findOne({ пользователь: пользователь._id, круг: @._.session.основной_круг }, @)
			
		#.сделать (круг) ->
		.сделать (session) ->
			query = { _id: { $gt: @._.session.последняя_прочитанная_новость }}
			#if круг?
			#	query.пользователь = { $in: круг.члены }
			
			db('news').find(query).toArray(@) # where чего $not_in круг.не_учитывать
			
		.сделать (новости) ->
			@.$.новости =
				новости: []
				беседы: {}
				обсуждения: {}
				
			for новость in новости
				@.$.новости.новости.push(новость._id.toString())
			
			if not @._.session.последние_сообщения?	
				return @.return(@.$.новости)
			
			пометить_новости = (новости, session, общение_во_множественном_числе) ->
				mark = (_id, сообщение) ->
					новости[общение_во_множественном_числе][_id] = сообщение
					
				if session.последние_сообщения[общение_во_множественном_числе]?
					for _id, сообщение of session.последние_сообщения[общение_во_множественном_числе]
						последние_прочитанные = session.последние_прочитанные_сообщения[общение_во_множественном_числе]
						if последние_прочитанные?
							if последние_прочитанные[_id]?
								if последние_прочитанные[_id] < сообщение
									mark(_id, сообщение)
						else
							mark(_id, сообщение)

			пометить_новости(@.$.новости, @._.session, 'беседы')
			пометить_новости(@.$.новости, @._.session, 'обсуждения')
			
			db('chat_info').findOne({}, @)
		
		.сделать (chat_info) ->
			общение = 'болталка'
			
			session = @._.session
			новости = @.$.новости
			
			mark = (сообщение) ->
				новости[общение] = сообщение
					
			if chat_info.последнее_сообщение?
				последнее_прочитанное = session.последние_прочитанные_сообщения[общение]
				последнее_сообщение = chat_info.последнее_сообщение
				if последнее_прочитанное?
					if последнее_прочитанное < последнее_сообщение
						mark(последнее_сообщение)
				else if последнее_сообщение?
					mark(последнее_сообщение)
								
			return @.return(@.$.новости)
		
		.go()