from twitterChecker import TwitterChecker
from personalSignpost import PersonalSignpost

twitterSignpost = TwitterChecker();

names = [ 'probst', 'mort___', 'narseo']
usersId = [13205142, 14162574, 82062101]



#twitterSignpost.checkFriendshipUserId (usersId[0], usersId[2])
#twitterSignpost.checkFriendshipUsername (names[1], names[2])

#Test lookup methods
#name = twitterSignpost.getScreenNameFromUserId(usersId[1]);
#print "name %s" %(name)

#output =  twitterSignpost.getUserIdFromScreenName (names[1])
#print "userid %s" %(output)

#output =  twitterSignpost.getUserName (usersId[1])
#print "name %s" %(output)

#output = twitterSignpost.getUserLocationFromId (usersId[2])
#print "Location %s for %s" %(output, usersId[2])
#output = twitterSignpost.getUserLocationFromScreenName (names[2])
#print "Location %s for %s" %(output, names[2])

narseoPs = PersonalSignpost(names[2])
