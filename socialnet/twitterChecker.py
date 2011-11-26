#!/usr/bin/python
# coding: utf-8

from twython import Twython
import json

class TwitterChecker:

	def getScreenNameFromUserId (self, userId):
		#Returns the screen name for an specific user id
		twitter = Twython()
		userData =  twitter.lookupUser(user_id = userId)
		print "Screen Name %s for userId %s" %(userData[0]['screen_name'], userId);
		return userData[0]['screen_name']
	
	def getUserIdFromScreenName (self, screenName):
		#Returns the user Id for a given screen name
		twitter = Twython()
		userData =  twitter.lookupUser(screen_name = screenName)
		print "User ID %s for user %s" %(userData[0]['id'], screenName)
		return userData[0]['id']
	
	def getUserName (self, userId):
		#Returns the real name for a given userId
		twitter = Twython()
		userData =  twitter.lookupUser(user_id = userId)
		print "Real name for %s (aka %s) is %s" %(userId, userData[0]['screen_name'], userData[0]['name'])
		return userData[0]['name']
	
	def getUserLocationFromId (self, userId):
		#Returns the user location for a given user
		twitter = Twython()
		userData =  twitter.lookupUser(user_id = userId)
		print "Location for %s -> %s" % ( userId, userData[0]['location'])
		return userData[0]['location']
		
	def getUserLocationFromScreenName (self, screenName):
		#Returns the user location for a given user
		twitter = Twython()
		userData =  twitter.lookupUser(screen_name = screenName)
		print "Location for %s -> %s" % ( screenName, userData[0]['location'])
		return userData[0]['location']
			
	def checkFriendshipUserId (self, userIdA, userIdB):
		#RETURNS TRUE IF USER_A FOLLOWS USER_B. It has to be symmetrical
		twitter = Twython()
		existsAB = twitter.checkIfFriendshipExists (user_id_a = userIdA, user_id_b = userIdB)
		existsBA = twitter.checkIfFriendshipExists (user_id_a = userIdB, user_id_b = userIdA)
		print "AB : %s" %(existsAB)
		print "BA : %s" %(existsBA)
		if (existsAB == True and existsBA == True):
			friendship = True	
			print "Friendship TRUE"
		else:
			friendship = False
			print "Friendship FALSE"	
		print "friendship between (%s, %s) %s" %(userIdA, userIdB, friendship)
		return friendship
		
	def checkFriendshipUsername (self,userNameA, userNameB):
		#RETURNS TRUE IF USER_A FOLLOWS USER_B. It has to be symmetrical
		twitter = Twython()
		existsAB = twitter.checkIfFriendshipExists (screen_name_a = userNameA, screen_name_b = userNameB)
		existsBA = twitter.checkIfFriendshipExists (screen_name_a = userNameB, screen_name_b = userNameA)
		print "AB : %s" %(existsAB)
		print "BA : %s" %(existsBA)
		if (existsAB == True and existsBA == True):
			friendship = True	
			print "Friendship TRUE"
		else:
			friendship = False
			print "Friendship FALSE"	
		print "friendship between (%s, %s) %s" %(userNameA, userNameB, friendship)
		return friendship
	
	def getUserEgoNetwork (self, userName):
		#Returns the ego centric net for a user
		twitter = Twython()
		followers = twitter.getFollowersIDs(screen_name = userName)
		friends = twitter.getFriendsIDs(screen_name = userName)
		symmetricFriendship =set(followers).intersection(set(friends))
		print "--------------FOLLOWERS: %d------------------" %(len(followers))
		for follower_id in followers:
			print "User with ID %s, is following %s" % ( follower_id, userName )
		print "--------------FRIENDSHIP: %d------------------" %(len(friends))
		for friends_id in friends:
			print "%s is friend with user with ID %s" % ( userName, friends_id )
		print "--------------SYMMETRIC: %d------------------" %(len(symmetricFriendship))
		return symmetricFriendship