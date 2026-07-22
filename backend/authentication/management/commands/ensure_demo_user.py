from django.core.management.base import BaseCommand

from authentication.demo import ensure_demo_user


class Command(BaseCommand):
    help = 'Ensure the shared demo user exists for guest access'

    def handle(self, *args, **options):
        user = ensure_demo_user()
        self.stdout.write(self.style.SUCCESS(f'Demo user ready: {user.username}'))
