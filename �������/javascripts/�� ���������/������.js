/**
 * Welcome page initialization
 */

var enter_window

var поле_пароля
var кнопка_отмены
var кнопка_входа

// create dialog
function initialize_enter_window()
{
	enter_window = $("#enter_window").dialog_window
	({
		'close on escape': true,
		'on open': function() { $('#enter_window input:first').focus() }
	})
	
	поле_пароля = enter_window.$element.find('input').eq(0)
	
	enter_window.$element.keydown(function(event) 
	{
		// if Enter key pressed
		if (event.keyCode == Event.Keys.enter) 
		{
			кнопка_входа.push()
			return false
		}
	})
	
	enter_window.register_controls
	(
		поле_пароля,
		кнопка_отмены,
		кнопка_входа
	)
}

// create dialog buttons
function initialize_enter_window_buttons()
{
	кнопка_отмены = activate_button('#enter_window .buttons .cancel', { 'prevent double submission': true })
	.does(function() { enter_window.close() })
	
	кнопка_входа = activate_button('#enter_window .buttons .enter', { 'prevent double submission': true })
	.does(function() { войти({ пароль: поле_пароля.val() }) }).submits(new Form(enter_window.$element.find('form').eq(0)))
}

function activate_button(selector, options)
{
	var element = $(selector)

	options = options || {}
	options.selector = selector

	return button.physics.classic(new text_button
	(
		element,
		Object.append
		(
			{
				skin: 'sociopathy',
				
				// miscellaneous
				'button type':  element.attr('type'), // || 'generic',
			},
			options
		)
	))
}
        
$(function()
{
    initialize_enter_window()
    initialize_enter_window_buttons()
	
	function проверить_адрес_на_вход()
	{
		if (!пользователь)
			if (get_hash() === "войти")
				enter_window.open()
	}
	
	проверить_адрес_на_вход()
	//window.onhashchange = проверить_адрес_на_вход
	
	$('.enter').live('click', function(event)
	{
		event.preventDefault()
		
		if (!пользователь)
			enter_window.open()
	})
		
	$('.logout').click(function(event)
	{
		event.preventDefault()
		выйти()
	})
})

function войти(data)
{
	loading_indicator.show()
	Ajax.post('/приложение/вход', data, 
	{
		ошибка: 'Не удалось войти',
		error: function(ошибка)
		{
			loading_indicator.hide()
			error(ошибка)
			поле_пароля.focus()
			кнопка_входа.unlock({ force: true })
		},
		ok: function(данные)
		{ 
			loading_indicator.hide()
			enter_window.close()
			
			window.location.reload()
			//info('Ваше имя: ' + данные.пользователь.имя) 
		} 
	})
}

function выйти()
{
	loading_indicator.show()
	Ajax.post('/приложение/выход', {}, 
	{
		ошибка: 'Не удалось выйти',
		error: function(ошибка)
		{
			loading_indicator.hide()
			error(ошибка)
		},
		ok: function(данные)
		{ 
			loading_indicator.hide()
			window.location.reload()
		} 
	})
}

Validation.вход =
{
	пароль: function(пароль)
	{
		if (пароль.length == 0)
			throw new custom_error('Введите ваш пароль')
	}
}