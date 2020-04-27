FROM nginx:alpine
vgavcja
COPY /build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]