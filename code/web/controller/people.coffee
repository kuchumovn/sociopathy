хранилище.bind 'people',
	выбрать: (настройки, возврат) ->
		условия = настройки.условия || {}
		@find(условия, { skip: настройки.с - 1, limit: настройки.сколько }).toArray возврат

http.get '/люди', (ввод, вывод) ->

	настройки =  {}

	if ввод.настройки.раньше == 'true'
		настройки.направление = 'назад'
		настройки.прихватить_границу = no
	else
		настройки.направление = 'вперёд'
		настройки.прихватить_границу = no
		
	цепь(вывод)
		.сделать ->
			if настройки.всего?
				return @.done()
			return хранилище.collection('people').count({}, @.в 'всего')
			
		.сделать ->
			if not ввод.настройки.с?
				skip = ввод.настройки.пропустить || 0
				return пользовательское.взять({}, { options: { limit: ввод.настройки.сколько, sort: [['$natural', -1]], skip: skip }}, @.в 'люди')
				
			сравнение_id = {}
			
			if настройки.направление == 'вперёд'
				сравнение_id = '$lte'
			else if настройки.направление == 'назад'
				сравнение_id = '$gte'
		
			if настройки.прихватить_границу == no
				if сравнение_id == '$lte'
					сравнение_id = '$lt'
				else if сравнение_id == '$gte'
					сравнение_id = '$gt'
					
			id_criteria = {}
			id_criteria[сравнение_id] = хранилище.collection('people').id(ввод.настройки.с)
				
			sort = null
			
			if настройки.направление == 'вперёд'
				sort = -1
			else if настройки.направление == 'назад'
				sort = 1
				
			пользовательское.взять({ _id: id_criteria }, { options: { limit: ввод.настройки.сколько, sort: [['$natural', sort]] }}, @.в 'люди')

		.сделать (люди) ->
			return @.done() if люди.length < ввод.настройки.сколько
			
			more_id_criteria  = {}
			sort = null
			
			if настройки.направление == 'назад'
				more_id_criteria = { $gt: люди[люди.length - 1]._id }
				sort = -1
			else if настройки.направление == 'вперёд'
				more_id_criteria = { $lt: люди[люди.length - 1]._id }
				sort = 1
				
			пользовательское.взять({ _id: more_id_criteria }, { options: { limit: 1 }}, @)
		
		.сделать (more) ->
			if more? && !more.пусто() > 0
				@.$['есть ещё?'] = yes
			else
				@.$['есть ещё?'] = no
				
			вывод.send(@.$)

global.получить_данные_человека = (address_name, вывод, возврат) ->
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ 'адресное имя': address_name }, @)

		.сделать (пользователь) ->
			if not пользователь?
				return вывод.send
					ошибка:
						текст: "Пользователь «#{address_name}» не состоит в нашей сети"
						уровень: 'ничего страшного'
				
			возврат null, пользователь

http.get '/человек', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			global.получить_данные_человека(ввод.настройки.адресное_имя, вывод, @.в '$')
			
		.сделать ->
			пользовательское.пользователь(ввод, @._.в 'пользователь')
			
		.сделать (пользователь) ->
			if not пользователь?
				return @.done()
			@.done()
			
		.сделать ->
			хранилище.collection('picture_albums').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
			
		.сделать (картинки) ->
			@.$['есть ли картинки?'] = !картинки.пусто()
			@.done()
			
		.сделать ->
			хранилище.collection('video_albums').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
			
		.сделать (видеозаписи) ->
			@.$['есть ли видеозаписи?'] = !видеозаписи.пусто()
			@.done()
			
		.сделать ->
			хранилище.collection('peoples_books').findOne({ пользователь: @.$._id }, @)
			
		.сделать (книги) ->
			if книги? && !книги.книги.пусто()
				@.$['есть ли книги?'] = yes
			@.done()
			
		.сделать ->
			хранилище.collection('diaries').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
			
		.сделать (diaries) ->
			@.$['ведёт ли дневник?'] = !diaries.пусто()
			@.done()
			
		.сделать ->
			хранилище.collection('journals').find({ пользователь: @.$._id }, { limit: 1}).toArray(@)
			
		.сделать (journals) ->
			@.$['ведёт ли журнал?'] = !journals.пусто()
			@.done()
			
		.сделать ->
			if not @._.пользователь?
				return @.done()
			хранилище.collection('circles').find({ пользователь: @._.пользователь._id }).toArray(@)
			
		.сделать (круги) ->
			if not круги
				return @.done()
			
			for круг in круги
				for член in круг.члены
					if член + '' == @.$._id + ''
						@.$.в_круге = круг
						return @.done()
					
			return @.done()
			
		.сделать ->
			вывод.send @.$
			
http.get '/человек/картинки/альбомы', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ 'адресное имя': ввод.настройки['адресное имя'] }, @)
			
		.сделать (человек) ->
			@.$.пользователь = { имя: человек.имя }
			хранилище.collection('picture_albums').find({ пользователь: человек._id }, { sort: [['_id', 1]] }).toArray(@.в 'альбомы')
			
		.сделать ->
			вывод.send @.$
	
http.get '/человек/картинки/альбом', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ 'адресное имя': ввод.настройки['адресное имя'] }, @._.в 'пользователь')
		
		.сделать (человек) ->
			@.$.пользователь = { имя: человек.имя }
			хранилище.collection('picture_albums').findOne({ пользователь: человек._id, id: ввод.настройки.альбом }, @.в 'альбом')
	
		.сделать (альбом) ->
			if not альбом?
				return вывод.send(альбом: { картинки: [] })
			хранилище.collection('pictures').find({ альбом: альбом._id }, { sort: [['_id', 1]] }).toArray(@)
			
		.сделать (картинки) ->
			@.$.альбом.картинки = картинки
			вывод.send @.$
			
http.get '/человек/видео/альбомы', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ 'адресное имя': ввод.настройки['адресное имя'] }, @)
			
		.сделать (человек) ->
			@.$.пользователь = { имя: человек.имя }
			хранилище.collection('video_albums').find({ пользователь: человек._id }, { sort: [['_id', 1]] }).toArray(@.в 'альбомы')
			
		.сделать (альбомы) ->
			for альбом in @.$.альбомы
				альбом.видео = []
			вывод.send(@.$)
		
http.get '/человек/видео/альбом', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			пользовательское.взять({ 'адресное имя': ввод.настройки['адресное имя'] }, @)
			
		.сделать (человек) ->
			@.$.пользователь = { имя: человек.имя }
			хранилище.collection('video_albums').findOne({ пользователь: человек._id, id: ввод.настройки.альбом }, @.в 'альбом')
			
		.сделать (альбом) ->
			if not альбом
				return вывод.send(альбом: { видео: [] })
			хранилище.collection('videos').find({ альбом: альбом._id }, { sort: [['_id', 1]] }).toArray(@)
			
		.сделать (видео) ->
			@.$.альбом.видео = видео
			вывод.send @.$
			
http.get '/сеть/черновик', (ввод, вывод) ->
	цепь(вывод)
		.сделать ->
			#console.log(ввод.настройки.что)
			вывод.send({})