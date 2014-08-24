class Demo
    constructor(); //empty
    
    //each task print 5 to 1
    procedure demo_thread(n:string)
        i:integer
        for i:=5 downto 1
            writeln(n + ': ' , i)
            sleep(100)

program ThreadDemo
    d:Demo = new Demo()
    run d.demo_thread('Task 1') //start task1
    run d.demo_thread('Task 2') //start task2
    writeln('I am done here.')
    sleep(1000)