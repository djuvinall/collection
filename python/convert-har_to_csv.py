import argparse
import json
import os
import pandas as pd


def convert_har_to_csv(input_file, output_file):
    # Verify the input file actually exists
    if not os.path.exists(input_file):
        print(f"Error: The file '{input_file}' does not exist.")
        return

    print(f"Reading {input_file}...")
    with open(input_file, "r", encoding="utf-8") as f:
        try:
            har_data = json.load(f)
        except json.JSONDecodeError:
            print("Error: Failed to parse file. Ensure it is a valid JSON/HAR file.")
            return

    flat_entries = []

    # Ensure the HAR structure is valid before parsing
    if "log" not in har_data or "entries" not in har_data["log"]:
        print("Error: Invalid HAR file structure.")
        return

    for entry in har_data["log"]["entries"]:
        flat_entries.append({
            "timestamp": entry.get("startedDateTime"),
            "load_time_ms": entry.get("time"),
            "method": entry.get("request", {}).get("method"),
            "url": entry.get("request", {}).get("url"),
            "status": entry.get("response", {}).get("status"),
            "mime_type": entry.get("response", {}).get("content", {}).get("mimeType"),
            # Keeps nested elements intact within single CSV cells
            "request_headers": json.dumps(entry.get("request", {}).get("headers")),
            "response_headers": json.dumps(entry.get("response", {}).get("headers")),
            "cookies": json.dumps(entry.get("request", {}).get("cookies")),
        })

    # Save to CSV
    df = pd.DataFrame(flat_entries)
    df.to_csv(output_file, index=False)
    print(f"Success! Data successfully saved to: {output_file}")


if __name__ == "__main__":
    # Setting up the command line argument configurations
    parser = argparse.ArgumentParser(
        description="Convert a HAR file to a lossless CSV format completely offline."
    )

    # Required argument: The path to the HAR file
    parser.add_argument(
        "-i",
        "--input",
        required=True,
        help="Path to the input .har file (e.g., -i traffic.har)",
    )

    # Optional argument: Custom output name (defaults to 'network_log.csv')
    parser.add_argument(
        "-o",
        "--output",
        default="network_log.csv",
        help="Path/name for the output CSV file (Default: network_log.csv)",
    )

    args = parser.parse_args()

    # Run the function with parsed flags
    convert_har_to_csv(args.input, args.output)
