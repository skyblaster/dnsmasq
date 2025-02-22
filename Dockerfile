# Build stage
FROM alpine:latest AS builder

# Define the version as a build argument
ARG DNSMASQ_VERSION=v2.91rc5

# Install build dependencies
RUN apk add --no-cache \
    git \
    make \
    gcc \
    musl-dev \
    linux-headers

# Clone the dnsmasq repository and checkout the specific tag
WORKDIR /src
RUN git clone https://thekelleys.org.uk/git/dnsmasq.git && \
    cd dnsmasq && \
    git checkout tags/${DNSMASQ_VERSION}

# Compile
WORKDIR /src/dnsmasq
RUN make CFLAGS="-Os -s" LDFLAGS="-static" all

# Ensure the dnsmasq binary is executable and strip symbols to reduce the binary size
RUN chmod +x src/dnsmasq && strip src/dnsmasq

# Create necessary directories and set permissions
RUN mkdir -p /var/lib/misc && \
    touch /var/lib/misc/dnsmasq.leases && \
    chown -R nobody:nobody /var/lib/misc

# Final stage
FROM scratch

# Set the working directory
WORKDIR /usr/local/bin

# Copy the necessary files for the nobody user and group
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy the compiled dnsmasq binary from the builder stage
COPY --from=builder /src/dnsmasq/src/dnsmasq .

# Copy the /var/lib/misc directory with correct permissions
COPY --from=builder /var/lib/misc /var/lib/misc

# Explicitly set the user to nobody
USER nobody

# Expose DNS, DHCP, TFTP, and Proxy DHCP ports
EXPOSE 53/udp 53/tcp 67/udp 69/udp 4011/udp

# Set the entrypoint to run dnsmasq
ENTRYPOINT ["dnsmasq"]
