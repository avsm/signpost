#!/usr/bin/python

import sqlite3
import exceptions
import os
import datetime

class SqliteController:
	
	#Wrapper for the Sqlite DB
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
			c.execute('''create table if not exists policies (policyId integer primary key, policyData text unique)''')
			c.execute('''create table if not exists userpolicies  (userId integer, policyId integer)''')
			#include default policy
			c.execute("""insert into policies (policyId,policyData) values (0, 'ALL')""");
			#TODO: Include all the triggers, specially when data is removed (e.g. users, etc)
			#Trigger that removes the entries for a user on userIds and policies table
			c.execute("""create trigger remove_user DELETE ON users BEGIN DELETE userIds where userId = old.userId; DELETE userpolicies where userId = old.userId; END""")
			#Trigger that removes any reference on the userPolicies
			c.execute("""create trigger remove_policy DELETE ON policies BEGIN DELETE userpolicies where policyId = old.policyId; END""")
			conn.commit()
			c.close()
			print 'Tables created for the 1st time'
		else:
			#TODO: Is it necessary to create the triggers again if the tables are already defined?
			print 'Tables already created'


	#Checks whether a given user (based on twitter Id) has been inserted in users' table
	#Returns 1 (True) or 0 (False)
	def checkIfUserExists (self, userId):
		print "-----"
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
		print "-----"
		print 'Creating new user %s, %s %s' %(username, signpostName, userId)		
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor();		
		c.execute("insert into users values (null, ?, ?)", (username,userId))		
		conn.commit()
		now = datetime.datetime.now()
		#Try to get userId		
		c.execute("select * from users where name=?", (username,))
		entries = c.fetchone()
		userId = None
		if not entries is None:
			#there's an entry for this username
			userId = entries[0]
		print "Assigned UserId: %s" %(userId)		
		c.execute("insert into userIds values (?, ?, ?, ?)", (userId, signpostName, None, now.strftime("%Y-%m-%d %H:%M:%s")))
		conn.commit()
		c.close()
	
	#Removes a user entry.
	def removeUser (self, username):
		print "-----"
		print "Removing user %s" %(username)
		#TODO: Test if the triggers work
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute ("delete from users where username=?", (username,))
		conn.commit()
		c.close()
		
	#adds a new policy
	def addPolicy (self, policy):
		print "-----"
		print "Add a new policy: " %(policy)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("insert into policies values (null, ?)", (policy,))
		conn.commit()
		c.close()
		return policyId
	
	#Removes a policy
	def removePolicy (self, policy):
		print "-----"
		#TODO, check if triggers work
		print "Remove an existing policy: " %(policy)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("delete from policies where policyData=?", (policy,))
		conn.commit()
		c.close()
		return policyId
		
	#Links a public key with a given user
	def addUserKey (self, signpostName, key):
		print "-----"
		print "Ready to add key to user %s" %(signpostName)
		#Considering at the moment that there's a key per signpostName
		#TODO, if there's one per user, then we need to update all the
		#entries for the user that is linked to this signpost name
		#It depends on what we will agree
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		now = datetime.datetime.now()
		c.execute('update userIds set publickey=?, timestamp=? where signpostname=?', (key, now.strftime("%Y-%m-%d %H:%M:%s"), signpostName, ))
		conn.commit()
		c.close()
	
	#Cleans a key associated to a user
	def cleanUserPublicKey (self, signpostName):
		print "-----"
		#NOTE: it doesn't remove the full entry, Just removes the public key
		self.linkKeyToUser(signpostName, None)
		print "Public key associated with %s was cleaned" %(signpostName)
		
	#Returns a public key for a given signpostName. 
	#TODO: If there's any change on whether the keys are associated to users or to signpost names, 
	#(i.e. per device), it should be done here
	def getKeyFromUser (self, signpostName):
		print "-----"
		print "getKeyFromUser %s" %(signpostName)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("select publickey from userIds where signpostname=?", (signpostName,))
		key = c.fetchone()
		conn.commit()
		c.close()
		print "key value: %s" %(key)
		return key
	
	#Returns the policyId for a given policy
	def getPolicyId (self, policy):
		print "-----"
		print "Getting the policyID for policy: %s" %(policy)		
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("select policyId from policies where policyData=?", (policy,))
		policyId = c.fetchone()
		c.close()
		print "PolicyId for %s: %s" %(policy, policyId)
		return policyId
		
	#Returns the policy value for a given policyId
	def getPolicy (self, policyId):
		print "-----"
		print "Getting policy for policyId: %s" %(policyId)		
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("select policyData from policies where policyId=?", (policyId,))
		policy = c.fetchone()
		print "Policy associated with PolicyId %s: %s" %(policyId, policy)
		return policy
	
	#Returns a list of policyIds assigned to a given user
	#Returns just the integers, in order to retrieve its value, use getPolicyValue
	def getUserPolicyIds (self, username):
		print "-----"
		print 'Finding user policies associated with user: %s' %username
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		#Need to find userId first
		userId = getUserIdFromSignpostName(username)
		policies = None
		if not userId is None:
			c.execute("select policyId from userpolicies where userId=?", (userId))
			policies = c.fetchall()
		c.close()
		print "----"
		print "Policies assigned to user %s:" %(username)
		for policy in policies:
			print "PolicyId: %s" %(policy)			
			#TODO: we need to make some decission process depending on how restrictive they are
			#in order to return the most restrictive one
		return policies
			
	#links a policy for a given user
	def linkPolicyToUser(self, userName, policyId):
		print "-----"
		print "Maps policyId %s with user: %s" %(policyId, userName)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		#Get userId		
		userId = getUserIdFromSignpostName(username)
		if not userId is None:
			#Assume that there isn't any entry already
			c.execute("insert into userpolicies values (?, ?)", (userId, policyId,))
			conn.commit()
		c.close()
	
	#Removes a given policy associated with a user
	def removePolicyToUser(self, userName, policyId):
		print "-----"
		print "Removes Policy %s for %s" %(policyId, userName)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		#Get userId		
		userId = getUserIdFromSignpostName(username)
		if not userId is None:
			c.execute("delete from userpolicies where userId=?, policyId=?", (userId, policyId, ))
			conn.commit()
		c.close()
	
	#Removes all the policies for a given user
	#TODO
	def cleanAllUserPolicies (self, userName):
		print "-----"
		print "Clean all Policies for %s" %(userName)
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		#Get userId		
		userId = getUserIdFromSignpostName(username)
		if not userId is None:
			c.execute("delete from userpolicies where userId=?", (userId,))
			conn.commit()
		c.close()
		
		
	#Returns the userId for a userName
	def getUserIdFromSignpostName (self, userName):
		print "-----"
		print 'Finding userId for %s' %signpostName
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("select userId from users where name=?", (userName, ))
		userId = c.fetchone()
		c.close()
		print "UserId for userName %s: %s" %(signpostName, userId)
		return userId
		
	#Returns the userId for a signpostName
	def getUserIdFromSignpostName (self, signpostName):
		print "-----"
		print 'Finding userId for %s' %signpostName
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute("select userId from userIds where signpostname=?", (signpostName, ))
		userId = c.fetchone()
		c.close()
		print "UserId for signpostName %s: %s" %(signpostName, userId)
		return userId				
	
	#Prints the list of users stored in the database. Mainly for debugging purposes
	def printContacts (self):
		print "-----"
		print "Printing all the users stored"
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute('select * from users')
		for row in c:
			print row
		c.close()
	
	#Prints the list of signpostNames stored in the database. Mainly for debugging purposes
	def printSignpostNames (self):
		print "-----"
		print "Printing all the signpost names stored"
		conn = sqlite3.connect(self.dbPath)
		c = conn.cursor()
		c.execute('select * from userIds')
		for row in c:
			print row
		c.close()
			