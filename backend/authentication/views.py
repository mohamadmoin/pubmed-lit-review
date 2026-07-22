from rest_framework import generics, permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.response import Response
from rest_framework.settings import api_settings
from rest_framework.views import APIView

from .serializers import AuthTokenSerializer, UserSerializer


class CreateUserView(generics.CreateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {
                'user': UserSerializer(user, context=self.get_serializer_context()).data,
                'token': token.key,
            },
            status=status.HTTP_201_CREATED,
        )


class CreateTokenView(ObtainAuthToken):
    serializer_class = AuthTokenSerializer
    permission_classes = [permissions.AllowAny]
    renderer_classes = api_settings.DEFAULT_RENDERER_CLASSES

    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {
                'token': token.key,
                'user_id': user.pk,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
            }
        )


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request.user.auth_token.delete()
        return Response({'message': 'Successfully logged out'})


class ValidateTokenView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        token_key = request.data.get('token')
        if not token_key:
            return Response({'error': 'Token is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = Token.objects.get(key=token_key)
            if not token.user.is_active:
                return Response({'error': 'User is not active'}, status=status.HTTP_401_UNAUTHORIZED)
            return Response(
                {
                    'valid': True,
                    'user_id': token.user.id,
                    'username': token.user.username,
                    'email': token.user.email,
                }
            )
        except Token.DoesNotExist:
            return Response({'valid': False, 'error': 'Invalid token'}, status=status.HTTP_401_UNAUTHORIZED)
