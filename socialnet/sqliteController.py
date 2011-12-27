#!/usr/bin/python

import sqlite3
import exceptions
import os
import datetime

class SqliteController:
	
	def __init__ (self, dbPath):
		self.dbPath = dbPath
		
	#Creates the tables in case the program is being executed for the first time
	#or the db has been deleted
	def createDb (self):
		if not os.path.exists(self.dbPath):
			conn = sqlite3.connect(self.dbPath)
			c = conn.cursor();
			c.execute('''create table if not exists userIds (userId integer, signpostname text primary key, publickey text, timestamp date)''')
			c.execute('''create table if not exists users (userId integer primary key, name varchar unique, twitterApiId varchar unique)''')
			c.execute('''create table if not exists policies (policeId integer primary key, policyData text)''')
			c.execute('''create table if not exists userpolicies  (userId integer, policyId integer)''')
			#include default policy
			c.execute("""insert into policies (policeId,policyData) values (0, 'ALL')""");			conn.commit()
			c.close()
			print 'Tables created for the 1st time'
		else:
			print 'Tables already created'
	
	#Returns a policy for a given user
	def findUserPolicy (username):
		print 'Finding user policy for %s' %username
		#TODO
		
	#Checks whether a given user (based on twitter Id) has been inserted in users' table
	def checkIfUserExists (self, userId):
		print "Check if user %s exists" %(userId)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor();
		c.execute("select userId from users where twitterApiId=?", (userId,))
		entries = c.fetchone()
		if entries is None:
			print "User %s does not exist in DB" %(userId)
			return 0
		else:
			print "User %s exists in DB" %(userId)
			return 1
			
	#Adds a user both the user table and the userId table
	def createUser (self, username, signpostName, userId):
		print 'Creating new user %s, %s %s' %(username, signpostName, userId)		
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor();		
		c.execute("insert into users values (null, ?, ?)", (username,userId))		
		conn.commit()
		now = datetime.datetime.now()
		#Try to get userId		
		c.execute("select * from users where name=?", (username,))
		entries = c.fetchone()
		userId = entries[0]
		print "Assigned UserId: %s" %(userId)		
		c.execute("insert into userIds values (?, ?, ?, ?)", (userId, signpostName, None, now.strftime("%Y-%m-%d %H:%M:%s")))
		conn.commit()
		c.close()
	
	#Prints the list of users stored in the database. Mainly for debugging purposes
	def printContacts (self):
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute('select * from users')
		for row in c:
			print row
		c.close()
	
	#Prints the list of signpostNames stored in the database. Mainly for debugging purposes
	def printSignpostNames (self):
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute('select * from userIds')
		for row in c:
			print row
		c.close()
			