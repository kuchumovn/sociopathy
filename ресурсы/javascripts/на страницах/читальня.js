function initialize_page()
{
	Подсказки.подсказка('В этом разделе вы можете читать и писать заметки на всевозможные темы.')

	insert_search_bar_into($('#panel'))
	$('.on_the_right_side_of_the_panel').css('right', $('#search').outerWidth(true) + parseInt($('#search').css('right')) + 'px')
	
	$('#categories').disableTextSelect()

	var путь_к_разделу
	var match = путь_страницы().match(/читальня\/(.+)/)
	if (match)
		путь_к_разделу = match[1]
		
	new Data_templater
	({
		data:
		{
			подразделы:
			{
				template_url: '/страницы/кусочки/раздел читальни.html',
				item_container: $('#categories'),
				postprocess_element: function(item)
				{
					return $('<li/>').append(item)
				}
			},
			заметки:
			{
				template_url: '/страницы/кусочки/заметка раздела читальни.html',
				item_container: $('#articles'),
				postprocess_element: function(item)
				{
					return $('<li/>').append(item)
				}
			}
		},
		conditional: $('#category_list_block[type=conditional]'),
		done: categories_loaded
	},
	new  Data_loader
	({
		url: '/приложение/раздел читальни',
		parameters: { путь: путь_к_разделу }
	}))

	$(window).resize(resize_categories_list)
	resize_categories_list()
}

function categories_loaded()
{
	Режим.разрешить('правка')
}

function resize_categories_list()
{
	function calculate_categories_width(count)
	{
		var Category_width = 250
		var Category_side_spacing = 40
	
		return count * (Category_width + (Category_side_spacing * 2))
	}
	
	var available_width = parseInt($('#content').width())
	
	var count = 0
	var width = 0
	var suitable_width = width
	while (true)
	{
		count++
		width = calculate_categories_width(count)
		
		if (width <= available_width)
			suitable_width = width
		else
			break
	}
	
	$('#categories').width(suitable_width).css('left', (available_width - suitable_width) / 2 + 'px')
}