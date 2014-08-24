uses TomoSys
class Fork
    id, holder:integer
    constructor(i:integer)
        id:=i
        set_state(on_table)
    procedure set_holder(pid:integer)
        holder:=pid
    state on_hand
        writeln('P', holder, ' gets F', id)
    state on_table
        if(holder > 0)
            writeln('P', holder, ' puts down F', id)
        set_holder(0)
    event pick_up(pid:integer)
        from on_table to on_hand call set_holder(pid)
    event put_down(pid:integer)
        from on_hand to on_table, when (holder=pid)
class Phil
    pid, interval:integer
    lfork, rfork:Fork
    shared_lock:Lock
    done:boolean
    constructor(i:integer, l,r:Fork, s_lock:Lock)
        pid:=i
        lfork:=l
        rfork:=r
        done:=false
        interval:=round(1000/pid)
        shared_lock:=s_lock
    state hungry
        writeln('+++ P', pid, ' is hungry.')
        shared_lock.lock()
        while (lfork.holder <> pid) or (rfork.holder <> pid)
            await raise lfork.pick_up(pid), rfork.pick_up(pid)
            sleep(interval)
        shared_lock.unlock()
    state eating
        writeln('+++ P', pid, ' is eating.')
        sleep(interval)
        raise lfork.put_down(pid), rfork.put_down(pid)
    state thinking
        writeln('--- P', pid, ' is thinking.')
        sleep(interval)
    state done
        writeln('P', pid, ' is done.')
    event eat()
        from hungry to eating
    event think()
        from eating to thinking
    event thinking_over(last_round:boolean)
        from thinking to done, when (last_round)
        from thinking to hungry      
    procedure loop(num_cycles:integer)
        set_state(hungry)
        i:integer
        for i:=1 to num_cycles
            await raise eat()
            await raise think()
            await raise thinking_over(i=num_cycles)
            sleep(interval)
        done:=true
program StatePhilos
    forks:array[5] of Fork
    phils:array[5] of Phil
    shared_lock:Lock = new Lock()
    i:integer
    for i:=0 to 4
        forks[i] := new Fork(i+1)
    for i:=0 to 4
        phils[i] := new Phil(i+1,forks[i],forks[(i+1)%5],shared_lock)
        run phils[i].loop(5)
    for i:=0 to 4
        while(phils[i].done=false)
            sleep(1000)