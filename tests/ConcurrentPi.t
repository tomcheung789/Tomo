uses math, TomoSys

class ConPi 
	chan:Channel
	
	constructor(c:Channel)
		chan := c
	
	function pi(num:integer) float
		k:integer
		for k:=0 to num - 1
			run term(k)  //create thread to call term method.
		f:float
		f:=0
		for k:=0 to num - 1
			f:= f + chan.receive()
		return f
		
	procedure term(k:float)
		chan.send( 4*power(-1,k)/(2*k+1) )

program ConcurrentPi
	p:ConPi
	p:= new ConPi(new Channel(5000))
	writeln(FloatToStr(p.pi(5000)))