FROM alpine:3.22 AS build
RUN echo "built for $(uname -m)" > /built.txt
FROM alpine:3.22
COPY --from=build /built.txt /built.txt
CMD ["cat", "/built.txt"]
