# import:py from sentence_transformers { SentenceTransformer, util }
# import:py base64;
# node Hastags {}

node Profile {
    has username: str;
    has count_tag: dict = {};
    has followees: list = [];
}

node Tweet {
    has content: str;
    # has tag: str;
    # has embedding: str;
}

node Comment {
    has content: str;
    # has embedding: str;
}

# edge post {}

# edge tag {
#     has name: str;
# }

# edge like {}

# glob model:SentenceTransformer = SentenceTransformer(
#     'sentence-transformers/multi-qa-mpnet-base-cos-v1'
# );

# glob Hastag:Hastags = Hastags();

walker visit_profile {
    can visit_profile with `root entry {
        visit [-->(`?Profile)] else {
            here ++> (new_profile := Profile());
            visit new_profile;
        }
    }
}

walker update_profile :visit_profile: {
    has username: str;

    can update_profile with Profile entry {
        here.username = self.username;
        report here;
    }
}

walker get_profile :visit_profile: {
    has username: str;

    can get_profile with Profile entry {
        report here;
    }
}

walker follow_request :visit_profile: {
    has profile_id: str;

    can follow with Profile entry {
        here.followees.append(self.profile_id);
        # here +:follow():+> &self.profile_id;
    }
}

walker load_tweets :visit_profile: {
    can load_tweets with Tweet entry {
        report {tweet: here};
    }
}

walker load_feed :visit_profile: {
    can load with Profile entry {
        for user in here.followees {
            user_node = &user;
            Jac.allow_root(here, NodeAnchor.ref(user), "READ");
            user_node spawn load_tweets();
            Jac.disallow_root(here, NodeAnchor.ref(user));
            # for tweet in [user-->(`?Tweet)] {
            #     feed.append(
            #         (tweet.content, user.username, len([tweet<-:like:-]))
            #     );
            # }
        }
        # report feed;

    }
}

# walker update_tag {
#     can update with Tweet entry {
#         :g: Hastag ;

#         here <+:tag(here.tag):+ Hastag;
#     }
# }

walker create_tweet :visit_profile: {
    has content: str;
    # has tag: str="";
    can tweet with Profile entry {
        embedding_str = base64.b64encode(model.encode(self.content)).decode(
            'utf-8'
        );

        # here +:post():+> (tweet := Tweet(self.content, self.tag, embedding_str));
        here +:post():+> (tweet := Tweet(self.content, embedding_str));
        # Jac.unrestrict(tweet, 1);
        # tweet spawn update_tag();
        visit tweet;
    }

    can report_tweet with Tweet entry {
        report here;
    }
}

walker like_tweet :visit_profile: {
    has tweet_id: str;

    can like with Profile entry {
        here +:like():+> (tweet := &self.tweet_id);
    }
}

walker comment_tweet :visit_profile: {
    has tweet_id: str;
    has content: str;

    can comment with Profile entry {
        embedding_str = base64.b64encode(model.encode(self.content)).decode(
            'utf-8'
        );
        (tweet := &self.tweet_id) ++> (comment := Comment(self.content, embedding_str));
        Jac.unrestrict(comment, 1);
        report jid(comment);
    }
}

walker search_tweets :visit_profile: {
    has query: str;

    can search with Profile entry {
        :g: Hastag ;


        result = [];
        if (i := [Hastag-:tag:name == self.query:->]) {
            tweets = i;
            for tweet in tweets {
                user = [tweet<-:post:-][0];
                result.append(
                    [tweet.content, user.username, len([tweet<-:like:-])]
                );
            }
        } else {
            tweets = [];
            for user in [here-:follow:->] {
                for tweet in [user-->(`?Tweet)] {
                    tweets.append(
                        (tweet.content, user.username, len([tweet<-:like:-]))
                    );
                }
            }
            docs = [tweet[0] for tweet in tweets];
            scores = util.dot_score(
                model.encode(self.query),
                model.encode(docs)
            )[0].cpu().tolist();
            doc_score_pairs = list(zip([i for (i, _) in enumerate(docs)], scores));
            doc_score_pairs = sorted(
                doc_score_pairs,
                key=(with x: int can x[1]), reverse=True
            );
            result = [tweets[i] for (i, _) in doc_score_pairs[:5]];
        }
        report result;
    }
}