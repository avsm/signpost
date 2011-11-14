#!/usr/bin/python
# coding: utf-8

#Thread that is responsible for: 
#a) Getting social net and cache it. Load it on boot
#b) Check if a user is part of someone's social net
#c) Generate keys for users
#d) Store friends' keys
#e) Extend address book (name, public key, social net accounts, affiliations)

#from twython import Twython

from threading import Thread
from twitterChecker import TwitterChecker
import json
import time
import os.path
import tweepy
import simplejson, oauth
import webbrowser
#from OauthAccess import OauthAccess
#from OauthRequest import OauthRequest


#Access token	410104745-5bHJ0GjL2touskpxDhanzXfTGnoGFiW8f39Y6Vd4
#Access token secret	Gq9Qx2zg0W7ItfRxnTXfA4JtF9MJGHithtQoIdNtaI
#Access level	Read-only

class PersonalSignpost:

	def __init__ (self, user_screen_name, password):
		self.CONSUMER_KEY = "6HggnCjXRY2Z81bV8abcA"
		self.CONSUMER_SECRET = "b0MSaJjSJwX51QPyjr1MMtrf00rBupD82rhdhVB8rM"
		#Duty cycle used to update/find changes in social net
		self.DUTY_CYCLE = 60;
		print "Personal signpost"
		self.user_screen_name = user_screen_name
		#Local social_net cache:
		self.password = password
		print "PS for %s created" %(user_screen_name)
		self.authenticate()
		#Should load socialNet list from file (in memory)		
		self.user_address_book_filename = user_screen_name + ".ab"
		#Check if file exists
		try
			open(self.user_address_book_filename)
			#Read file
			
		except IOError as e:
			print "File %s doesn't exist" (% self.user_address_book_filename)
			#Read input-output
			
		t = Thread (target = self.runFunc, args = ())
		t.start()
		
		
	#method to authenticate a user in twitter with Oauth
	def authenticate (self):	
		auth = tweepy.OAuthHandler(self.CONSUMER_KEY, self.CONSUMER_SECRET)
		try:
			redirect_url = auth.get_authorization_url()
		except tweepy.TweepError:
			print 'Error! Failed to get request token.'
		#print "Redirect URL -> %s" %(redirect_url)
		#Redirect to the browser in order to get the Oauth pin (i.e. verifier)
		new = 2 # open in a new tab, if possible
		# open a public URL in the webbrowser
		webbrowser.open(redirect_url,new=new)
		verifier = raw_input('PIN Verifier:')
		#Now send to twitter the verified token:
		try:
			auth.get_access_token(verifier)
		except tweepy.TweepError:
			print 'Error! Failed to get access token.'
		self.api = tweepy.API(auth)
		#To test if it works, uncomment the following line (posting something in your twitter wall)
		#newTweet = raw_input('Enter a new tweet: ')
		#api.update_status(newTweet)
	
	#thread. Checks periodically for changes in the social net. It should handle the requests to
	#verify whatever happens in the social net.
	def runFunc (self):
		
		self.twitterSignpost = TwitterChecker()
		
		while True:
			print "user: %s - Value: %d" %(self.user_screen_name, i)
			time.sleep(self.DUTY_CYCLE)
			
		
	def updateSocialNet (self):
		#update user's social network
		print "ready to update social net for %s" %(self.user_screen_name)
		#check if user address book exists
		if os.path.isfile (self.user_address_book_filename):
			print "Address book file exists: %s" %(self.user_address_book_filename)
			#Read address book and load it in memory
		else:
			print "Address book file doesn't exist %s" %(self.user_address_book_filename)
			#if don't -> Create one and save it in a file
			f = open ('./'+self.user_address_book_filename, 'w')
			print "Making address book for: %s in %s" %(self.user_screen_name, f)
			symmetricFriendship = self.twitterSignpost.getUserEgoNetwork(self.user_screen_name)
			#Save it in a file. JSON format {user_id, user_real_name, user_screen_name, user_location, public_key, affiliation(s)}
			print "List of friends: "
			for friends_id in symmetricFriendship:
				print friends_id