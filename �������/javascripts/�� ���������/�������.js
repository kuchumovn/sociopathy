/**
 * Welcome page initialization
 */

var join_dialog
var gender_chooser
var joined_message
var join_form_slider

var join_dialog_cancel_button
var join_dialog_next_button
var join_dialog_done_button

// activate join button
function initialize_join_button()
{
	button.physics.classic(new image_button
	(
		"#join_button", 
		{
			action: function() { join_dialog.open() }
		}
	))
}

// create join dialog
function initialize_join_dialog()
{
	join_dialog = $("#join_dialog").dialog_window
	({
		'close on escape': true,
		'on open': function() { $('#join_dialog input:first').focus() }
	})
	
	join_dialog.register_controls
	(
		join_dialog_cancel_button,
		join_dialog_next_button,
		join_dialog_done_button, 
		join_form_slider
	)
	
	join_form_slider.set_container(join_dialog.$element)
	join_form_slider.when_done(function() { join_submission(join_form_slider.data()) })
}

// create join dialog buttons
function initialize_join_dialog_buttons()
{
	join_dialog_cancel_button = activate_button('#join_dialog .buttons .cancel', { 'prevent double submission': true })
	.does(function() { join_dialog.close() })
	
	join_dialog_next_button = activate_button('#join_dialog .buttons .next')
	.does(function() { join_form_slider.next(function() { $('#join_dialog .slider .slide:eq(' + (join_form_slider.slider.index - 1) + ') input:first').focus() }) })
	
	join_dialog_done_button = activate_button('#join_dialog .buttons .done', { 'prevent double submission': true })
	.does(function() { join_form_slider.done() })
}

// create join dialog slider
function initialize_join_form_slider()
{
	join_form_slider = new form_slider
	({
		selector: "#join_dialog .slider",
		buttons:
		{
			next: join_dialog_next_button,
			done: join_dialog_done_button
		},
		fields:
		{
			имя:
			{
				validate: function(name) { if (name.length == 0) throw new custom_error($._("page 'welcome', dialog 'join', error, name, empty")) }
			},
			пол:
			{
				control: gender_chooser,
			},
			откуда:
			{
			},
			пароль:
			{
				validate: function(name) { if (name.length == 0) throw new custom_error('Пароль будет нужен для входа') }
			}
		}
	})
}

// create gender chooser
function initialize_gender_chooser()
{
	gender_chooser = new image_chooser
	(
		"#join_dialog .gender .chooser",
		{
			target: "#join_dialog .gender input[type=hidden]"
		}
	)
}

function activate_buttons()
{
	return Array.prototype.slice.call(arguments).map(function(options)
	{
		return activate_button(options)
	})
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

function initialize_page()
{
	var приглашение = получить_настройку_запроса('приглашение')
	
	if (приглашение)
		Ajax.get('/приложение/приглашение/проверить', { приглашение: приглашение },
		{
			error: 'Не удалось установить Вашу личность. Попробуйте позже',
			ok: function(данные)
			{
				if (!данные.приглашение)
					return
					
				initialize_join_button()

				initialize_join_dialog_buttons()
				initialize_gender_chooser()
				initialize_join_form_slider()
				initialize_join_dialog()

				$('.slider label').disableTextSelect()
				$('#join_form .gender .chooser').disableTextSelect()
			}
		})	
}

// actions

// submit join request
function join_submission(data)
{
	loading_indicator.show()
	Ajax.put('/приложение/прописать', data, 
	{ 
		error: 'Не удалось прописаться', 
		ok: function(данные) 
		{ 
			loading_indicator.hide()
			join_dialog.close()
			Message.info('Ваш номер: ' + данные.ключ) 
		} 
	})
}