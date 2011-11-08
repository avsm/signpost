#!/usr/bin/python
# coding: utf-8

#Thread that is responsible for: 
#a) Getting social net and cache it. Load it on boot
#b) Check if a user is part of someone's social net
#c) Generate keys for users
#d) Store friends' keys
#e) Extend address book (name, public key, social net accounts, affiliations)

from twython import Twython
from threading import Thread
from twitterChecker import TwitterChecker
import json
import time
import os.path


class PersonalSignpost:
	def __init__ (self, user_screen_name):
		#No need to do oath -> user_screen_name can be stored somewhere (store social net)
		self.user_screen_name = user_screen_name
		self.user_address_book_filename = user_screen_name + ".ab"
		print "PS for %s created" %(user_screen_name)
		t = Thread (target = self.runFunc, args = ())
		t.start()
		self.twitterSignpost = TwitterChecker();
				
	#thread
	def runFunc (self):
		self.updateSocialNet()
		
		i = 0
		while True:
			print "user: %s - Value: %d" %(self.user_screen_name, i)
			time.sleep(5)
			i = i + 1
		
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