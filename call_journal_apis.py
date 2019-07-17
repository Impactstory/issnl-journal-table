from multiprocessing.pool import ThreadPool
import requests
import argparse
import os
from time import time
from time import sleep
import datetime
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy import sql, orm, and_

from app import db
from util import elapsed
from util import safe_commit

class Journal(db.Model):
    issn_l = db.Column(db.Text, primary_key=True)
    issns = db.Column(JSONB)
    api_raw_crossref = db.Column(JSONB)
    api_raw_issn = db.Column(JSONB)

    def __repr__(self):
        return u'<Journal ({issn_l})>'.format(
            issn_l=self.issn_l
        )

def call_issn_api(query_text):
    if not query_text:
        return None

    response_data = None

    url_template = u"https://portal.issn.org/resource/ISSN/{}?format=json"
    url = url_template.format(query_text)
    print url
    r = requests.get(url)
    if r.status_code == 200:
        try:
            response_data = r.json()
        except ValueError:
            pass

    return response_data


def call_crossref_api(query_text):
    if not query_text:
        return None

    response_data = None

    url_template = u"https://api.crossref.org/journals/{}"
    url = url_template.format(query_text)
    print url
    r = requests.get(url)
    if r.status_code == 200:
        try:
            response_data = r.json()
        except ValueError:
            pass

    # print response_data
    return response_data

def call_api(api_fn, query_texts):
    for query_text in query_texts:
        result = api_fn(query_text)
        if result:
            print 'got a result'
            return result

    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run stuff.")

    parsed = parser.parse_args()

    start = time()

    while True:
        query = Journal.query.filter(and_(Journal.api_raw_crossref == None, Journal.api_raw_issn == None))\
            .order_by(Journal.issn_l)\
            .limit(50)
        journal_metadata_objs = query.all()

        if not journal_metadata_objs:
            print "done!"
            exit()

        for my_obj in journal_metadata_objs:
            # try all issns, issnl-l first
            issns = set(my_obj.issns)
            issns.discard(my_obj.issn_l)
            issns = [my_obj.issn_l] + list(issns)

            if not my_obj.api_raw_crossref:
                print 'getting crossref response for {}'.format(my_obj.issn_l)
                my_obj.api_raw_crossref = call_api(call_crossref_api, issns) or 'none'

            # slow. only do it if we didn't get a crossref response
            if not my_obj.api_raw_issn and my_obj.api_raw_crossref == 'none':
                print 'getting issn response for {}'.format(my_obj.issn_l)
                my_obj.api_raw_issn = call_api(call_issn_api, issns) or 'none'

            db.session.merge(my_obj)

        safe_commit(db)

        db.session.remove()
        print 'finished update'

