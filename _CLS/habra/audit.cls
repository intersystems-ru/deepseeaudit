/// Пример использования подсистемы аудита в прикладном коде
Class habra.audit Extends %CSP.Page
{

/// Регистрация прикладных ( пользовательских ) типов событий 
ClassMethod EventTypesRegister() As %Status
{
	#; Типы событий регистрируются через класс из системной области %SYS
	set ns = $namespace, $namespace = "%SYS"
	
	#; set status = ##class(Security.Events).Create( Source, Type, Name, Description )
	set statusC = ##class(Security.Events).Create( "habra", "audit", "create",	"Create event example" ) 
	set statusR = ##class(Security.Events).Create( "habra", "audit", "read",	"Read event example" )
	set statusU = ##class(Security.Events).Create( "habra", "audit", "update",	"Update event example" )
	set statusD = ##class(Security.Events).Create( "habra", "audit", "delete",	"Delete event example" )
	
	set $namespace = ns
	set status = ( statusC && statusR && statusU && statusD )
	
	Quit status
}

/// Простая страница с несколькими кнопками
ClassMethod OnPage() As %Status
{
 
 &html<<!DOCTYPE html><html><head></head><body>
	
<h3>Hello, #($username)#!</h3><hr>

<form method='post'>
	<button name='create'>Create</button>
	<button name='read'  >Read  </button>
	<button name='update'>Update</button>
	<button name='delete'>Delete</button>
</form>

</body></html>>

 Quit 1
}

/// Разбираем параметры формы
ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	
	#; форма отправит на сервер единственный параметр - имя кнопки
	#; http://[server]/[app]/[class]?name=
	set name = $order( %request.Data("") )	;узнаем какая кнопка вызвала отправку

	#; сохраняем в журнал аудита ( Source, Type, Name, EventData, Description )
	set status = ##class(%SYSTEM.Security).Audit( "habra", "audit", name, "нажал кнопку", "1984" )

	Quit 1
}

}

