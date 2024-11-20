test get_graph{
    root spawn visit_profile(username="kashmith");
    root spawn create_tweet(username="kashmith", content="first tweet");
    root spawn create_tweet(username="kashmith", content="second tweet");
    root spawn update_profile(username="kashmith", new_username="nisakya");
    root spawn get_profile(username="nisakya");
    print(dotgen(root));
}