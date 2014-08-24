class Light
	chan:Channel
	
	constructor(c:Channel)
		chan:=c
		set_state(red)
		
	state red
		writeln('Car Stop: Red ')
		chan.send('safe')
		
	state red_yellow
		writeln('Car Ready: Red -> Yellow ')
		chan.send('notsafe')
		
	state yellow
		writeln('Car Warning: Yellow ')
		
	state green
		writeln('Car Go: Green ')
		
	event cycle()
		from green to yellow
		from yellow to red
		from red to red_yellow
		from red_yellow to green

class PedestrianLight
	chan:Channel
	
	constructor(c:Channel)
		chan:=c
		set_state(green)
		run wait_for_command()
	
	procedure wait_for_command()
		while (chan.is_open)
			if (chan.receive() = 'safe')
				raise walk()
			else
				raise stand()
		
	state red
		writeln('Pedestrian Stand: Red ')
		
	state green
		writeln('Pedestrian Walk: Green ')
		
	event stand()
		from green to red
		
	event walk()
		from red to green
		
program TrafficChannel
	chan:Channel
	chan:= new Channel()  //create a channel
	l:Light
	l:= new Light(chan)
	p:PedestrianLight
	p:= new PedestrianLight(chan)
	i:integer
	for i:=0 to 5
		raise l.cycle()
		sleep(2000)