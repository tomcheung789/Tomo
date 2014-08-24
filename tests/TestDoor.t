class Door
    constructor()
        set_state(closed) //initial state
        
    state opened
        writeln('Door is opened.')
        
    state opening
        writeln('Door is opening.')
        
    state closed
        writeln('Door is closed.')
    
    state closing
        writeln('Door is closing.')
        
    event open()
        from closed to opening
        from closing to opening
    
    event close()
        from opened to closing
        from opening to closing
    
    event finish()
        from opening to opened
        from closing to closed

program TestDoor
    d:Door = new Door()
    await raise d.open()
    await raise d.close()
    await raise d.open()
    await raise d.finish()