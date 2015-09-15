## JavaZone video matching utility

This matches up EMS sessions and Vimeo vidoes based on title

You'll need to create a config.yaml based on config.yaml.sample.

To get the vimeo lines - log in to https://developer.vimeo.com/apps as
javazone - select JavaZone video mapper - OAuth tab. For the key and
secret - just take them - for access token - scroll down - there's a
pre-created one.

```
vimeo:
  key: 'Client ID'
  secret: 'Client Secret'
  token: 'Access token'
  token_secret: 'Access token secret'
  album: 'Numeric ID of the album on Vimeo for the videos for the year you're matching'
ems:
  url: 'The sessions URL on EMS for the year you're matching'
  
```

### Running

    $ bundle
    $ bundle exec ./match.rb > mapping.txt 2> missing.txt

