#!/usr/bin/env python3
"""
Startup Timer Script

Makes an OpenAI-compatible API call to http://{host}:{port}/v1
and records the time it takes to get a response back.

Examples:
    # Default (localhost:8000)
    python startup_timer.py

    # Custom host and port
    python startup_timer.py --host 192.168.0.30 --port 32020

    # Specific model
    python startup_timer.py --host 192.168.0.30 --port 32020 \
        --model deepseek-ai/DeepSeek-V4-Flash-DSpark

    # Custom prompt and extended timeout
    python startup_timer.py --host 192.168.0.30 --port 32020 \
        --model deepseek-ai/DeepSeek-V4-Flash-DSpark \
        --prompt "Say 'hello world'" --timeout 3600

    # Using environment variables
    LLMD_HOST=192.168.0.30 LLMD_PORT=32020 \
        LLMD_MODEL=deepseek-ai/DeepSeek-V4-Flash-DSpark \
        python startup_timer.py
"""

import argparse
import os
import time
from openai import OpenAI

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8000
DEFAULT_MODEL = "gpt-3.5-turbo"
DEFAULT_TIMEOUT = 30 * 60  # 30 minutes


def main():
    parser = argparse.ArgumentParser(
        description="Measure startup time for an OpenAI-compatible endpoint."
    )
    parser.add_argument(
        "--host",
        type=str,
        default=os.environ.get("LLMD_HOST", DEFAULT_HOST),
        help=f"Target host (default: {DEFAULT_HOST}, env: LLMD_HOST)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("LLMD_PORT", DEFAULT_PORT)),
        help=f"Target port (default: {DEFAULT_PORT}, env: LLMD_PORT)",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=os.environ.get("LLMD_MODEL", DEFAULT_MODEL),
        help=f"Model name to use in the request (default: {DEFAULT_MODEL}, env: LLMD_MODEL)",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        default="Hello, respond with the word 'ready'.",
        help="Prompt to send to the model (default: 'Hello, respond with the word \\'ready\\'.')",
    )
    parser.add_argument(
        "--api-key",
        type=str,
        default=os.environ.get("LLMD_API_KEY", "password"),
        help="API key sent as Bearer token (default: 'password', env: LLMD_API_KEY)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Request timeout in seconds (default: {DEFAULT_TIMEOUT})",
    )

    args = parser.parse_args()

    base_url = f"http://{args.host}:{args.port}/v1"
    print(f"Connecting to {base_url}")
    print(f"Model: {args.model}")
    print(f"API Key: {args.api_key}")
    print(f"Timeout: {args.timeout}s")
    print(f"Prompt: {args.prompt}")
    print()

    client = OpenAI(
        base_url=base_url,
        api_key=args.api_key,
        timeout=args.timeout,
        max_retries=0,
    )

    start_time = time.monotonic()
    print(f"Start time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("Sending request...")

    try:
        response = client.chat.completions.create(
            model=args.model,
            messages=[{"role": "user", "content": args.prompt}],
            stream=False,
        )
        elapsed = time.monotonic() - start_time

        print(f"Response received at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Elapsed time: {elapsed:.2f}s ({elapsed/60:.2f}m)")
        print()
        print("Response content:")
        print(response.choices[0].message.content)

    except Exception as e:
        elapsed = time.monotonic() - start_time
        print(f"Request failed after {elapsed:.2f}s ({elapsed/60:.2f}m)")
        print(f"Error: {e}")
        raise


if __name__ == "__main__":
    main()
