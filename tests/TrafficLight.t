class light

	from_red:boolean
	
	constructor()
		set_state(red)
		from_red:=true
	
	state red
		from_red:=true
		writeln('Stop: Red  ')
		
	state yellow
		writeln('!: Yellow  ')
		sleep(300)
		if(from_red)
			raise cycle(false)
		else
			raise cycle(true)
			
	state green
		from_red:=false
		writeln('Go: Green  ')
		
	event cycle(tostop:boolean)
		from green to yellow
		from red to yellow
		from yellow to green, when(tostop=false)
		from yellow to red, when(tostop)
		
program TrafficLight
	l:light
	l:=new light()
	i:integer
	for i:=0 to 5
		raise l.cycle(false)
		sleep(1000)
