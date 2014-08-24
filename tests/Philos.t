uses TomoSys

class Fork
	id:integer
	holder:integer
	flock:Lock
	
	constructor(i:integer)
		id:=i
		flock := new Lock()
	
	procedure picked_by(pid:integer)
		flock.lock()
		if (holder = 0)
			holder := pid
			writeln('   P'+ IntToStr(pid) + ' gets F' +IntToStr(id))
		flock.unlock()
	
	procedure dropped_by(pid:integer)
		flock.lock()
		if (holder = pid)
			writeln('   P'+ IntToStr(pid) + ' puts down F' +IntToStr(id))
			holder := 0
		flock.unlock()

class Phil
	pid:integer
	lfork:Fork
	rfork:Fork
	s:integer
	done:boolean
	
	constructor(i:integer,l:Fork,r:Fork)
		pid:=i
		self.lfork:=l
		self.rfork:=r
		s:=trunc(1000/pid)
		done:=false
	
	procedure eat()
		lfork.picked_by(pid)
		sleep(s)
		rfork.picked_by(pid)
		sleep(s)
		writeln('   +++ P'+ IntToStr(pid) + ' is eating.')
		sleep(s)
		lfork.dropped_by(pid)
		sleep(s)
		rfork.dropped_by(pid)
		
	procedure think()
		writeln('   --- P'+ IntToStr(pid) + ' is thinking.')
		sleep(s)
	
	procedure go(num_cycles:integer)
		i:integer
		for i:=0 to num_cycles - 1
			eat()
			think()
		writeln('   P'+ IntToStr(pid) + ' is done.')
		done:=true
	
program Philos
	fork1,fork2,fork3,fork4,fork5:Fork
	phil1,phil2,phil3,phil4,phil5:Phil
	fork1 := new Fork(1)
	fork2 := new Fork(2)
	fork3 := new Fork(3)
	fork4 := new Fork(4)
	fork5 := new Fork(5)
	phil1 := new Phil(1,fork1,fork2)
	phil2 := new Phil(2,fork2,fork3)
	phil3 := new Phil(3,fork3,fork4)
	phil4 := new Phil(4,fork4,fork5)
	phil5 := new Phil(5,fork5,fork1)
	run phil1.go(5)
	run phil2.go(5)
	run phil3.go(5)
	run phil4.go(5)
	run phil5.go(5)
	while(phil1.done=false)or(phil2.done=false)or(phil3.done=false)or(phil4.done=false)or(phil5.done=false)
		sleep(1000)
	free_object(fork1)
	free_object(fork2)
	free_object(fork3)
	free_object(fork4)
	free_object(fork5)
	free_object(phil1)
	free_object(phil2)
	free_object(phil3)
	free_object(phil4)
	free_object(phil5)