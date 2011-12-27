#!/usr/bin/python
# coding: utf-8

#Thread that is responsible for: 
#a) Authentication
#b) Getting social net and cache it (sqlite). Load it from db
#c) Store friends' keys in db
#d) Check if a user is part of someone's social net
#e) Generate keys for users
#f) Extend address book (name, public key, social net accounts, affiliations)



from threading import Thread
#TwitterChecker -> Public twitter API. no auth required but # requests limited
from twitterChecker import TwitterChecker
from sqliteController import SqliteController
import json
import time
import os.path
import tweepy
import webbrowser

class PersonalSignpost:
	def __init__ (self, user_screen_name):
		self.CONSUMER_KEY = "6HggnCjXRY2Z81bV8abcA"
		self.CONSUMER_SECRET = "b0MSaJjSJwX51QPyjr1MMtrf00rBupD82rhdhVB8rM"
		self.DBPATH = "./personalSp.db"
		self.KEY_PATH = "./twitterKey.sp"
		self.TWITTER_KEY_MSG_HEADER = "sp_pkey"
		#Duty cycle used to update/find changes in social net
		self.DUTY_CYCLE = 60;
		print "Personal signpost"
		self.user_screen_name = user_screen_name
		#Local social_net cache:
		print "PS for %s created" %(user_screen_name)
		self.authenticateTwitter()

		#print "Creating DB"
		self.sqliteController = SqliteController(self.DBPATH)
		self.dbConnector = self.sqliteController.createDb()
		
		#If we want to get by default all the twitter accounts for a user, execute that
		#try:
		#	self.updateSocialNetTweepy()
			
		#except:
		#	print "Error retrieving social net"
		#	pass
		
		#TODO: Implement a GUI for control of the static policies and the groups?	
			
		#Run process					
		#t = Thread (target = self.runFunc, args = ())
		#t.start()
		
	#method to authenticate a user in twitter with Oauth
	def authenticateTwitter (self):
			
		if not os.path.exists(self.KEY_PATH):
#			try:
				auth = tweepy.OAuthHandler(self.CONSUMER_KEY, self.CONSUMER_SECRET)
				print "Getting authorization from the user"
				redirect_url = auth.get_authorization_url()
				#print "Redirect URL -> %s" %(redirect_url)
				#Redirect to the browser in order to get the Oauth pin (i.e. verifier)
				new = 2 # open in a new tab, if possible
				# open a public URL in the webbrowser
				webbrowser.open(redirect_url,new=new)
				verifier = raw_input('PIN Verifier:')
				try:
					auth.get_access_token(verifier)
				except tweepy.TweepError:
					print 'Error! Failed to get access token.'
				
				f = open(self.KEY_PATH, 'w')
				#f.write(auth.access_token.key)
				print auth.access_token.key
				print auth.access_token.secret
				f.write(auth.access_token.key+','+auth.access_token.secret)
				#f.write(auth.access_token.secret)
				f.close()
#			except tweepy.TweepError:
#				print 'Error! Failed to get request token.'
		else:
			auth = tweepy.OAuthHandler(self.CONSUMER_KEY, self.CONSUMER_SECRET)
			print 'KEY ALREADY exists'
			#READ TOKEN FROM FILE
			f = open(self.KEY_PATH, 'r')
			line = f.readline()
			vals = str.split(line, ',')			
			f.close()			
			auth.set_access_token(vals[0], vals [1])		
		
		self.api = tweepy.API(auth)
		#To test if it works, uncomment the following line (posting something in your twitter wall)
		
	#Used to test authentication. Posts a new tweet entered by the user via its command line
	def post_test (self):
		newTweet = raw_input('Enter a new tweet: ')
		self.api.update_status(newTweet)
		
	#thread. Checks periodically for changes in the social net. It should handle the requests to
	#verify whatever happens in the social net.
	def runFunc (self):
		#Check if there's a change in the social net but 1st need to have sqllite running
		#TODO
		self.twitterSignpost = TwitterChecker()
		while True:
			print "user: %s" %(self.user_screen_name)
			time.sleep(self.DUTY_CYCLE)
			#Check changes in social net but needs to be integrated with Sebastian's
			#Save data in sqlite
	
	#Updates the social net using Twitter's contacts			
	def updateSocialNetTweepy (self):
		print "ready to update social net for %s using tweepy" %(self.user_screen_name)		
		print "Current list of users:"
		self.sqliteController.printContacts()
		#check if db has been created
		if not os.path.exists(self.DBPATH):
			print "Database has been removed. Creating a new one"
			self.dbConnector = self.sqliteController.createDb()
		#get a list of integers with friends and followers ids
		friendsIds = self.api.friends_ids()
		followersIds = self.api.followers_ids()
		print "Number of friends %s" %(len(friendsIds))
		print "Number of followers %s" %(len(followersIds))	
		symmetricFriendship =set(followersIds).intersection(set(friendsIds))
		print "SymmetricFriends: %s" %(len(symmetricFriendship))
		#Save friends on database
		for index in symmetricFriendship:
			if self.sqliteController.checkIfUserExists(index) == 0:
				print "User is not in DB. Retrieving data from Twitter and storing it in DB"
				try:
					userTmp = self.api.get_user(user_id=index)		
					print "----"
					print "Username: %s" %(userTmp.screen_name)
					#Save user on database
					print "Name: %s" %(userTmp.name)
					self.sqliteController.createUser(userTmp.name, userTmp.screen_name, index)
				except:
					print "Error trying to retrieve user: %s" %(index)
	
	def sendKeyToUser(self, user, key):		
		print "------"
		print "Ready to send public key to %s" %(user)
		toSend = self.TWITTER_KEY_MSG_HEADER+key		
		print "Key: %s" %(toSend)
		self.api.send_direct_message(screen_name=user, text=toSend)	
		print "------"
	
	#Gets if there is any change in the most recent public keys
	#TODO: It might be necessary to be changed as it only considers twitter-like names
	#We can send other names by making a header (plus it also needs to do some sorf of
	#packet fragmentation as the max size in twitter is 140 messages)
	def getLatestKeys (self):
		print "Ready to get latest public keys"
		messages = self.api.direct_messages()
		try:
			messages = self.api.direct_messages()
			counter = 1
			for message in messages:
				messageId = message.id
				print "Message id%s: %s - %s" %(messageId, counter, message.text)
				counter = counter + 1
				if message.text.startswith(self.TWITTER_KEY_MSG_HEADER):
					publicKey = message.text[7:]
					print "Retrieved Public Key From %s: %s" %(message.sender_screen_name, publicKey)
					#TODO: Save in database for this user
					self.sqliteController.addKeyToUser(message.sender_screen_name, publicKey)		
					self.api.destroy_direct_message(messageId)
					print "Message should be removed"
				else:
					print "No signpost key"
		except:
			print "Could not retrieve messages"
			pass

	def searchPeople (self, query):
		#TODO: Might be useful in order to expand someone's social net later but not at the moment.
		#Similar to find people button in twitter. We could search for someone and then add him/her
		#on the local address book
		#tweepy API -> self.api.search_users()
		print "Searching: %s" %(query)