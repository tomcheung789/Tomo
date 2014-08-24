interface A
    procedure do_somethings();

class B
    constructor();
    procedure b_name()
        writeln('B')

class C extends B implements A
    constructor()
        super()
    procedure do_somethings()
        writeln('implements')

program InherTest
    test:C = new C()
    test.b_name()
    test.do_somethings()