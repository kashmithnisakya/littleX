import:py logging;
import:py from jac_cloud.core.architype {NodeAnchor}

glob logger = logging.getLogger("littelX");

node profile {
    has username: str;
    has count_tag: dict = {};
    has followees: list = [];
}

node tweet {
    has content: str;
}

node comment {
    has content: str;
}

edge follow{}

edge like{}

walker visit_profile {
    has username: str;
    can visit_profile with `root entry {
        visit [-->(`?profile)] else {
            logger.info("Creating new profile");
            new_profile = here ++> profile(username=self.username);
            visit new_profile;
        }
    }
}

walker update_profile :visit_profile: {
    has new_username: str;

    can update_profile with profile entry {
        logger.info("Updating profile");
        here.username = self.new_username;
        report here;
    }
}

walker get_profile :visit_profile: {

    can get_profile with profile entry {
        logger.info(f"prfile info: {here}");
        report here;
    }
}

walker follow_request :visit_profile: {
    has profile_id: str;

    can follow with profile entry {
        here.followees.append(self.profile_id);
        logger.info(f"New followee addded: {self.profile_id}");
        here +:follow():+> &self.profile_id;
        report here;
    }
}

walker load_tweets :visit_profile: {

    can go_to_tweet with profile entry{
        visit [-->](`?tweet);
    }

    can load_tweets with tweet entry {
        logger.info(f"tweet loaded: {here}");
        report here;
    }
}

walker load_feed :visit_profile: {
    can load with profile entry {
        self.feed:list = [];
        for user in here.followees {
            user_node = &user;
            Jac.allow_root(user_node, NodeAnchor.ref(user), "READ");
            logger.info("Acess has given");
            tweet_nodes = [user_node-->(`?tweet)];
            logger.info("Getting all the tweets");
            logger.info(f"{user_node.username}'s tweets: {tweet_nodes}");
            self.feed.extend(tweet_nodes);
            Jac.disallow_root(here, NodeAnchor.ref(user));
            logger.info("Removing acess");
        }
    logger.info(f"all feeds: {self.feed}");
    report self.feed;
    }
}

walker create_tweet :visit_profile: {
    has content: str;
    can tweet with profile entry {
        tweet_node = here ++> tweet(content=self.content);
        visit tweet_node;
    }

    can report_tweet with tweet entry {
        logger.info(f"Creating new tweet: {here.content}");
        Jac.unrestrict(here, level="READ");
        report here;
    }
}

walker like_tweet :visit_profile: {
    has tweet_id: str;

    can like with profile entry {
        tweet_node = &self.tweet_id;
        here +:like():+> (tweet := tweet_node);
        logger.info(f"liked to a tweet: {tweet_node}");
        report tweet_node;
    }
}

walker comment_tweet :visit_profile: {
    has tweet_id: str;
    has content: str;

    can add_comment with profile entry {
        comment_node = here ++> comment(content=self.content);
        (tweet := &self.tweet_id) ++> comment_node[0];
        logger.info(f"comment added: {comment_node[0]}");
        report comment_node[0];
    }
}

walker print_root{
    can print_root with `root entry{
        print(dotgen(root));
    }
}