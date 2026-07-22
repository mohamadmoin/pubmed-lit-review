#!/usr/bin/env python3
"""
LitReview CLI — interact with the literature review API from the terminal.

Examples:
  python cli/litreview.py health
  python cli/litreview.py register --username demo --email demo@example.com --password secret123
  python cli/litreview.py login --username demo --password secret123
  python cli/litreview.py generate --token TOKEN --subject "CRISPR gene therapy" --description "Recent advances" --words 3000
  python cli/litreview.py list --token TOKEN
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

DEFAULT_BASE = os.getenv('LITREVIEW_API_URL', 'http://127.0.0.1:8002/api')


def _request(method: str, path: str, token: str | None = None, body: dict | None = None) -> dict:
    url = f"{DEFAULT_BASE.rstrip('/')}/{path.lstrip('/')}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
    if token:
        headers['Authorization'] = f'Token {token}'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        raise SystemExit(f"HTTP {exc.code}: {detail}") from exc


def cmd_health(_: argparse.Namespace) -> None:
    result = _request('GET', 'documents/status/')
    print(json.dumps(result, indent=2))


def cmd_register(args: argparse.Namespace) -> None:
    result = _request('POST', 'auth/register/', body={
        'username': args.username,
        'email': args.email,
        'password': args.password,
    })
    print('Registered. Token:', result.get('token'))


def cmd_login(args: argparse.Namespace) -> None:
    result = _request('POST', 'auth/login/', body={
        'username': args.username,
        'password': args.password,
    })
    print('Token:', result.get('token'))


def cmd_generate(args: argparse.Namespace) -> None:
    result = _request('POST', 'documents/generatedocument/', token=args.token, body={
        'subject': args.subject,
        'description': args.description,
        'word_count': args.words,
    })
    doc_id = result.get('document_id') or result.get('id')
    print('Generation started:', json.dumps(result, indent=2))
    if args.wait and doc_id:
        print('Polling process logs...')
        for _ in range(args.max_polls):
            time.sleep(args.interval)
            logs = _request('GET', f'documents/{doc_id}/process_logs/', token=args.token)
            messages = [entry.get('message', '') for entry in logs if isinstance(entry, dict)]
            if messages:
                print(messages[-1])
            content = _request('GET', f'documents/{doc_id}/', token=args.token)
            if content.get('status') == 'completed':
                print('Completed:', doc_id)
                return
        print('Timed out waiting for completion.')


def cmd_list(args: argparse.Namespace) -> None:
    result = _request('GET', 'documents/', token=args.token)
    print(json.dumps(result, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description='LitReview CLI')
    parser.add_argument('--api-url', default=DEFAULT_BASE, help='API base URL')
    sub = parser.add_subparsers(dest='command', required=True)

    sub.add_parser('health', help='Check API and Neo4j status').set_defaults(func=cmd_health)

    p_reg = sub.add_parser('register', help='Create account')
    p_reg.add_argument('--username', required=True)
    p_reg.add_argument('--email', required=True)
    p_reg.add_argument('--password', required=True)
    p_reg.set_defaults(func=cmd_register)

    p_login = sub.add_parser('login', help='Obtain auth token')
    p_login.add_argument('--username', required=True)
    p_login.add_argument('--password', required=True)
    p_login.set_defaults(func=cmd_login)

    p_gen = sub.add_parser('generate', help='Start literature review generation')
    p_gen.add_argument('--token', required=True)
    p_gen.add_argument('--subject', required=True)
    p_gen.add_argument('--description', default='')
    p_gen.add_argument('--words', type=int, default=3000)
    p_gen.add_argument('--wait', action='store_true', help='Poll until complete')
    p_gen.add_argument('--interval', type=int, default=5)
    p_gen.add_argument('--max-polls', type=int, default=120)
    p_gen.set_defaults(func=cmd_generate)

    p_list = sub.add_parser('list', help='List documents')
    p_list.add_argument('--token', required=True)
    p_list.set_defaults(func=cmd_list)

    args = parser.parse_args()
    global DEFAULT_BASE
    DEFAULT_BASE = args.api_url
    args.func(args)


if __name__ == '__main__':
    main()
