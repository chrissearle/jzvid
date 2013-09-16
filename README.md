## JavaZone video matching utility

This matches up EMS sessions and Vimeo vidoes based on title

You'll need vimeo advanced api consumer key/secret - and you can use the vimeo gem README and auth.rb to get the token info

You'll need a config.yaml file - fill out your consumer info, add the correct album ID for the year's vimeo album and add the EMS-redux
URL for the year's session collection.


### Running

    $ bundle
    $ bundle exec ./match.rb > mapping 2> missing

