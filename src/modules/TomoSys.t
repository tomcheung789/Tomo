// Copyright 2012-2014 Chong Cheung. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.
module TomoSys

uses SyncObjs, TomoType

class Lock extends TCriticalSection
	
	constructor()
		super()
		
	procedure lock()
		Enter()
		
	procedure unlock()
		Leave()


class Channel //everyone can send msg, but only one can receive it.
	
	is_open:boolean
	send_lock:Lock
	receive_lock:Lock
	write_lock:Lock
	msg:TomovarList
	max_msg_in_list:integer
	interval:integer
	
	constructor overload ()
		super()
		max_msg_in_list := 1
		init()
		
	constructor overload (max:integer)
		super()
		max_msg_in_list := max
		init()
	
	procedure init()
		is_open := true
		interval := 0
		send_lock:= new Lock()
		receive_lock:= new Lock()
		write_lock:= new Lock()
		msg := new TomovarList()
	
	procedure close()
		is_open := false
		
	procedure send(m:tomovar)
		if (is_open) 
			send_lock.lock()
			while (msg.Count = max_msg_in_list);
			//	sleep(interval)
			write_lock.lock()
			msg.add(m)
			write_lock.unlock()
			send_lock.unlock()
		
	function receive() tomovar
		if (is_open)
			tmp_var:tomovar
			receive_lock.lock()
			while (msg.Count = 0);
			//	sleep(interval)
			write_lock.lock()
			tmp_var := msg[msg.Count - 1]
			msg.Delete(msg.Count - 1)
			write_lock.unlock()
			receive_lock.unlock()
			return tmp_var
		else
			return CHANNEL_CLOSED
		
class ObjectChannel //everyone can send msg, but only one can receive it.
	
	is_open:boolean
	send_lock:Lock
	receive_lock:Lock
	write_lock:Lock
	msg:ObjectList
	max_msg_in_list:integer
	interval:integer
	
	constructor overload ()
		super()
		max_msg_in_list := 1
		init()
		
	constructor overload (max:integer)
		super()
		max_msg_in_list := max
		init()
	
	procedure init()
		is_open := true
		interval := 0
		send_lock:= new Lock()
		receive_lock:= new Lock()
		write_lock:= new Lock()
		msg := new ObjectList()
		
	procedure close()
		is_open := false
		
	procedure send(m:TObject)
		if (is_open) 
			send_lock.lock()
			while (msg.Count = max_msg_in_list);
			//	sleep(interval)
			write_lock.lock()
			msg.add(m)
			write_lock.unlock()
			send_lock.unlock()
		
	function receive() TObject
		if (is_open)
			tmp_var:TObject
			receive_lock.lock()
			while (msg.Count = 0);
			//	sleep(interval)
			write_lock.lock()
			tmp_var := msg[msg.Count - 1]
			msg.Delete(msg.Count - 1)
			write_lock.unlock()
			receive_lock.unlock()
			return tmp_var
		else
			return nil
		
class BroadcastChannel //a channel support multi sender receiver per object (one object can only join one time)
	is_open : boolean
	send_lock:Lock
	user_lock:Lock
	max_msg_in_list:integer
	users:ObjectList
	users_channel:ObjectList
	
	constructor overload ()
		super()
		max_msg_in_list := 1
		init()
		
	constructor overload (max:integer)
		super()
		max_msg_in_list := max
		init()
		
	procedure init()
		is_open:=true
		send_lock:= new Lock()
		user_lock:= new Lock()
		users := new ObjectList()
		users_channel := new ObjectList()
	
	procedure close()
		is_open := false
		while(users.Count > 0)
			leave(users[0])
		
	procedure join(user:TObject) 
		if(is_open)
			user_lock.lock()
			if(users.IndexOf(user) = -1)
				users.add(user)
				users_channel.add(new Channel(max_msg_in_list))
			user_lock.unlock()
	
	procedure leave(user:TObject) 
		user_lock.lock()
		idx:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			users.Delete(idx)
			//close before Delete
			c : Channel
			c := Channel(users_channel[idx])
			c.close()
			free_object(c)
			users_channel.Delete(idx)
		user_lock.unlock()
	
	procedure send(user:TObject, m:tomovar)
		send_lock.lock()
		idx:integer
		i:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			for i:=0 to users_channel.Count -1
				if(i <> idx)
					sendto : Channel
					sendto := Channel(users_channel[i])
					sendto.send(m)
		send_lock.unlock()
		
	function receive(user:TObject) tomovar
		if (not(is_open))
			return CHANNEL_CLOSED
		tmp_var:tomovar
		idx:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			recfrom : Channel
			recfrom := Channel(users_channel[idx])
			tmp_var := recfrom.receive()
			return tmp_var
		else
			return CHANNEL_NOTAMEMBER

class BroadcastObjectChannel //a channel support multi sender receiver per object (one object can only join one time)
	is_open : boolean
	send_lock:Lock
	user_lock:Lock
	max_msg_in_list:integer
	users:ObjectList
	users_channel:ObjectList
	
	constructor overload ()
		super()
		max_msg_in_list := 1
		init()
		
	constructor overload (max:integer)
		super()
		max_msg_in_list := max
		init()
		
	procedure init()
		is_open:=true
		send_lock:= new Lock()
		user_lock:= new Lock()
		users := new ObjectList()
		users_channel := new ObjectList()
	
	procedure close()
		is_open := false
		while(users.Count > 0)
			leave(users[0])
		
	procedure join(user:TObject) 
		if(is_open)
			user_lock.lock()
			if(users.IndexOf(user) = -1)
				users.add(user)
				users_channel.add(new ObjectChannel(max_msg_in_list))
			user_lock.unlock()
	
	procedure leave(user:TObject) 
		user_lock.lock()
		idx:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			users.Delete(idx)
			//close before Delete
			c : ObjectChannel
			c := ObjectChannel(users_channel[idx])
			c.close()
			free_object(c)
			users_channel.Delete(idx)
		user_lock.unlock()
	
	procedure send(user:TObject, m:TObject)
		send_lock.lock()
		idx:integer
		i:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			for i:=0 to users_channel.Count -1
				if(i <> idx)
					sendto : ObjectChannel
					sendto := ObjectChannel(users_channel[i])
					sendto.send(m)
		send_lock.unlock()
		
	function receive(user:TObject) TObject
		if (not(is_open))
			return nil
		tmp_var:TObject
		idx:integer
		idx:=users.IndexOf(user)
		if(idx <> -1)
			recfrom : ObjectChannel
			recfrom := ObjectChannel(users_channel[idx])
			tmp_var := recfrom.receive()
			return tmp_var
		else
			return nil
