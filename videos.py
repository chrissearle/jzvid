#!/usr/bin/env python

import sys
import os
import requests

args = sys.argv[1:]
urltemplate = "http://javazone.no/ems/server/events/0e6d98e9-5b06-42e7-b275-6abadb498c81/sessions/%s/attachments"

headers = {'Content-Type': 'application/vnd.collection+json'}

with open(args[0]) as f:
  for line in f:
    parts = line.split('\t')
    if len(parts) == 2:
      sessionid = parts[0].strip()
      vimeo = parts[1].strip()
      vimeoid = vimeo.split('/')[-1]
      url = urltemplate % sessionid
      template = '''{"template": { "data": [{"name": "name", "value": "%s"}, {"name": "href", "value": "%s"}]}}''' % (vimeoid, vimeo)
      r = requests.post(url, headers=headers, data=template)
      print '%s\t%s' % (url, r.status_code)