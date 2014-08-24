class Light
    chan:BroadcastChannel
    
    constructor(c:BroadcastChannel)
        chan:=c
        set_state(red)
        chan.join(self) //join to the channel to send msg.
        
    state red
        writeln('Car Stop: Red ')
        chan.send(self, 'safe')
        
    state red_yellow
        writeln('Car Ready: Red -> Yellow ')
        chan.send(self, 'notsafe')
        
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
    chan:BroadcastChannel
    id:integer
    
    constructor(c:BroadcastChannel, myid:integer)
        id:=myid
        chan:=c
        set_state(green)
        chan.join(self) //join to the channel to receive msg.
        run wait_for_command()
    
    procedure wait_for_command()
        while (chan.is_open)
            if (chan.receive(self) = 'safe')
                raise walk()
            else
                raise stand()
        
    state red
        writeln(IntToStr(id) + ' Pedestrian Stand: Red ')
        
    state green
        writeln(IntToStr(id) + ' Pedestrian Walk: Green ')
        
    event stand()
        from green to red
        
    event walk()
        from red to green
        
program TrafficBChannel
    chan:BroadcastChannel
    chan:= new BroadcastChannel()  //create a Broadcast Channel
    i:integer
    l:Light
    l:= new Light(chan)
    
    p: array[3] of PedestrianLight
    for i:=0 to 2
        p[i]:= new PedestrianLight(chan, i)
        
    for i:=0 to 5
        raise l.cycle()
        sleep(2000)