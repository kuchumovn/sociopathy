http_client = require('http')

пути = require 'path'
disk = require 'fs'

лекала = require 'jqtpl'

выполнить = require 'seq'

exports.собрать_и_отдать_страницу = (название, вывод) ->
	# останов цепи из catch'а пока не работает в seq.
	# форкнуть и внести эту доработку (мб в виде this.break(), а не в виде { break: true }).
	
	###
	# не работает, т.к. у меня Node.js не находит utf-8 файлы на диске (на винде)
	# в будущем ответ этот - класть в memcache, и брать оттуда nginx'ом минуя node.js
	.seq ->
		this null, [ 
			пути.join(process.cwd(), "ресурсы/лекала/основа.html"), 
			пути.join(process.cwd(), "ресурсы/страницы/#{название}.html") 
		]
		
	.flatten()
	
	.parEach (путь_к_файлу) ->
	
		пути.exists путь_к_файлу, (exists) =>
			if not exists
				this "Файл #{путь_к_файлу} не найден"
				return
				
			this null, путь_к_файлу
		
	.catch (ошибка) ->
		console.error ошибка
		вывод.send ошибка: ошибка
		break: true
		
	.seq (путь_к_основе, путь_к_содержимому_страницы) ->
		[путь_к_основе, путь_к_содержимому_страницы]
		
	.flatten()
	
	.parEach (путь_к_файлу) ->
		disk readFile путь_к_файлу, 'utf-8', this
	###
	
	адреса_содержимого = [ 
		"/лекала/основа.html", 
		"/страницы/#{название}.html"
	]
	
	выполнить()
		.seq ->
			this null, адреса_содержимого
			
		.flatten()
		
		.parEach (путь_к_файлу) ->
			
			key = new String(адреса_содержимого.indexOf(путь_к_файлу))
			
			options = 
				host: 'localhost',
				port: 8081,
				path: путь_к_файлу
			
			request = http_client.get options, (response) =>
				headers = JSON.stringify(response.headers)
		
				data = ''
				response
					.on 'data', (chunk) ->
						data += chunk 
						
					.on 'end', =>
						this.into(key)(null, data)
						
			request.on 'error', (error) ->
				this.into(key)(error)
	
		.catch (ошибка) ->
			console.error ошибка
			вывод.send ошибка: ошибка
			break: true
		
		# приходится использовать индексы - недоработка seq'а (форкнуть и изправить)
		.seq ->
			лекала.template('основа', @vars['0'])
			вывод.send(лекала.tmpl 'основа', название: название, содержимое: @vars['1'])
			#delete лекала.template['основа'];
		
		.catch (ошибка) ->
			console.error ошибка
			вывод.send ошибка: ошибка
			break: true