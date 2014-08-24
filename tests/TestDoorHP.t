class Door
    hp:integer
    door_name:string
    constructor(n:string)
        hp:= 3
        door_name:= n
        set_state(opened)
        
    procedure need_fix()
        writeln('Please fix the door.')
    
    state opened
        hp:=hp-1
        writeln(door_name, ' Door opened.  ')
        
    state closed
        writeln(door_name, ' Door closed.  ')
        
    state broken
        writeln(door_name, ' OMG the door is broken.  ')
        
    event switch_door()
        from opened to broken call need_fix(), when(hp=0)
        from closed to broken call need_fix(), when(hp=0)
        from opened to closed
        from closed to opened

program TestDoorHP
    d1:Door = new Door('A')
    d2:Door = new Door('B')
    i:integer
    for i:=5 downto 1
        raise d1.switch_door(), d2.switch_door()
        sleep(1000)