﻿function initialize_page()
{
	$('#reset_database').click(function(event)
	{
		event.preventDefault()
		
		Ajax.post('/приложение/хранилище/заполнить', 
		{
			ошибка: 'Не удалось заполнить хранилище',
			ok: 'Хранилище заполнено'
		})
	})
	
	$('#update_database').click(function(event)
	{
		event.preventDefault()
		
		Ajax.post('/приложение/хранилище/изменить', 
		{
			ошибка: 'Не удалось изменить хранилище',
			ok: 'Хранилище изменено'
		})
	})
	
	$('#get_invite').click(function(event)
	{
		event.preventDefault()
		
		Ajax.post('/приложение/приглашение/выдать', 
		{
			ошибка: 'Не удалось выдать приглашение',
			ok: function(data)
			{
				info(data.ключ)
			}
		})
	})
	
	$('#add_users').click(function(event)
	{
		event.preventDefault()
		
		Ajax.post('/приложение/хранилище/создать_пользователей', 
		{
			ошибка: 'Не удалось создать пользователей',
			ok: 'Пользователи созданы'
		})
	})
}