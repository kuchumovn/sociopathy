var enter_window

var войти

(function()
{
	var кнопка_отмены
	var кнопка_входа
	
	var login_form
	
	var поле_имени
	var поле_пароля
		
	// create dialog
	function initialize_enter_window()
	{
		enter_window = $("#enter_window").dialog_window
		({
			'close on escape': true,
			'on open': function() { $('#enter_window input:first').focus() }
		})
		
		поле_имени = enter_window.content.find('input').eq(0)
		поле_пароля = enter_window.content.find('input').eq(1)
		
		enter_window.on_enter = function()
		{
			кнопка_входа.push()
		}
		
		login_form = new Form(enter_window.content.find('form').eq(0))
		
		кнопка_отмены = text_button.new('#enter_window .buttons .cancel', { 'prevent double submission': true, physics: 'fast' })
		.does(function() { enter_window.close() })	
		
		кнопка_входа = text_button.new('#enter_window .buttons .enter', { 'prevent double submission': true })
		.does(function() { войти({ имя: поле_имени.val(), пароль: поле_пароля.val() }) }).submits(login_form)
		
		enter_window.register_controls
		(
			login_form,
			кнопка_отмены,
			кнопка_входа
		)
		
		$(document).on('keydown', function(event)
		{
			if (Клавиши.поймано(Настройки.Клавиши.Вход, event))
				if (!пользователь)
					enter_window.open()
		})
		
		$('.enter').on('click', function(event)
		{
			event.preventDefault()
			
			if (!пользователь)
				enter_window.open()
		})
		
		$('.logout').on('click', function(event)
		{
			event.preventDefault()
			выйти()
		})
	}
	
	function проверить_адрес_на_вход()
	{
		if (!пользователь)
			if (get_hash() === "войти")
				enter_window.open()
	}
	
	$(document).on('page_loaded', function()
	{
		if (first_time_page_loading)
			initialize_enter_window()
		
		проверить_адрес_на_вход()
		//window.onhashchange = проверить_адрес_на_вход
	})

	войти = function(data)
	{
		var loading = loading_indicator.show()
		page.Ajax.post('/приложение/вход', data)
		.ошибка(function(ошибка)
		{
			loading.hide()
			error(ошибка)
			поле_пароля.focus()
			кнопка_входа.unlock({ force: true })
		})
		.ok(function(данные)
		{
			loading.hide()
			loading_page({ full: true })
			enter_window.close()
			
			if (data.go_to)
				return window.location = data.go_to
				
			window.location.reload()
		})
	}
	
	function выйти()
	{
		var loading = loading_indicator.show()
		page.Ajax.post('/приложение/выход')
		.ошибка(function(ошибка)
		{
			loading.hide()
			error(ошибка)
		})
		.ok(function(данные)
		{ 
			loading.hide()
			loading_page({ full: true })
			
			window.location = '/'
		})
	}
})()