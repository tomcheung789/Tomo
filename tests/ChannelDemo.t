uses TomoSys, TomoType

class Demo
    chan:Channel
    constructor(c:Channel)
        chan:=c
    procedure sender(n:string)
        i:integer
        for i:=0 to 4
            writeln(n + ': send ',i) 
            chan.send(i) //send 0,1,2,3,4
            sleep(100)
    procedure receiver(n:string)
        while(chan.is_open) //is channel opening
            writeln(n + ': receive ', chan.receive()) //receive

program ChannelDemo
    d:Demo = new Demo(new Channel()) //pass a new channel to d
    run d.sender('Task 1') //start sender
    run d.receiver('Task 2') //start receiver
    sleep(1000)