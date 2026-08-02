# --- Hey: Add LLM reasoning to your ZShell ---

# @TODO: Use `script [-a -r -q -t] ~/.hey/history.log`
# This prevents us from using eval "$cmd" which is potentially dangerous

# 1. Configuration
export HEY_MODEL="gemma4:e4b-mlx"
export HEY_API_URL="http://localhost:11434/api/generate"

LOG_DIR="$HOME/.hey/logs"
LOG_FILE="$LOG_DIR/session.log"

# Usage: _debug "<CATEGORY>" "<TEXT>"
function _debug() {
    local debug="0"
    local debug_color="#56B4E9"
    if [[ $debug == 1 ]]; then
        print -Pn "%F{$debug_color}($1:)%f" "$2" "\n"
    fi
}

# Usage: _think
function _think() {
    # Print thinking message
    print -Pn "%F{$think_color}Thinking...%f\r"
}

function _hey_logic() {
    local user_prompt="$1"

    local system_prompt="You are a Z Shell assistant on a Macintosh system.
    You will be asked to determine how to perform a certain task in a Z Shell environment.
    Return ONLY the shell command to execute. 
    Do not format markdown, no explanations, just the raw code.
    The command must be ONE line of code."

    local system_prompt_summary="You are a Z Shell assistant on a Macintosh system.
    You will be provided with a question of how to perform a command in Z Shell on a Macintosh system.
    Return a summary of what the user is asking in ONE short, simple sentence.
    DO NOT include the shell command itself as part of your response.
    Start the summary sentence with a verb and do not say YOU or THE USER, and keep the sentence simple.
    If the command is destructive, begin the summary with 'DESTRUCTIVE! '.
    If the command takes large amounts of time, begin the summary with 'SLOW! '.
    This output is displayed in a terminal environment, format the output as such.
    Do not include conversational intro or outro.
    Wrap lines at 80 characters to fit standard terminal windows."

    local error_color="#D55E00"
    local think_color="#FDF1A9"
    local info_color="#0072B2"
    local debug_color="#56B4E9"

    # Print thinking message
    _think

    # Construct json payload for curl request
    local summary_payload="$(jq -n --arg model "$HEY_MODEL" --arg prompt_s "$user_prompt" --arg system_s "$system_prompt_summary" '{model: $model, prompt: $prompt_s, system: $system_s, stream: false}')"
    _debug "Summary Payload" "$summary_payload"

    local response_summary="$(curl -s "$HEY_API_URL" --data-binary "$summary_payload")"
    _debug "Summary Response" "$response_summary"

    # Construct json payload for curl request
    local payload="$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')"
    _debug "Payload" "$payload"

    # 3. Call the API using the file as input
    # We use --data-binary to ensure no character translation happens
    local response="$(curl -s "$HEY_API_URL" --data-binary "$payload")"
    _debug "Response" "$response"

    # Print thinking message
    local clean_text_summary="$(printf '%s\n' "$response_summary" | jq -r ".response")"
    print -Pn "%F{$info_color}$clean_text_summary%f\n"

    if [[ $? -ne 0 ]]; then
        print -Pn "%F{$error_color}(Error: Curl failed)%f\n"
        return 1
    fi

    # 4. Parse the response from the file
    local clean_text="$(printf '%s\n' "$response" | jq -r ".response")"
    _debug "Clean Text" "$clean_text"

    if [[ -z "$clean_text" || "$clean_text" == "null" ]]; then
        print -Pn "%F{$error_color}(Error: LLM returned nothing or invalid JSON)%f\n"
    else
        local command_text="$clean_text"
        print -z "$command_text"
    fi
}

function _hey_info() {
    setopt local_options
    setopt extended_glob

    local error_color="#D55E00"
    local think_color="#FDF1A9"
    local info_color="#0072B2"
    local debug_color="#56B4E9"

    local debug="0"

    local system_prompt="You are a Z Shell knowledge expert on a Macintosh system.
    You will be provided with a shell command the result of running that command.
    Provide information about what the shell command does and summarize what the provided result means.
    Do not call this result explanation a summary or review.
    This output is displayed in a terminal environment, format the output as such.
    Do not include conversational intro or outro.
    Wrap lines at 80 characters to fit standard terminal windows.
    Strip markdown blocks and markdown headers, do not use triple backticks or markdown fences or headings."

    if [[ $1 =~ ^[[:space:]]*$ ]]; then
        local last_command=$(history | tail -n 1)
        local clean_last_command="${last_command##[0-9 ]#}"

        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}get info about: last command%f\n"
            print -Pn "%F{$debug_color}$clean_last_command%f\n"
        fi

        # Print thinking message
        print -Pn "%F{$think_color}Thinking...%f\r"

        local user_prompt="The last command the user ran is: $last_command
        Give a brief explanation of what the last command does and what the result says."

        # Construct json payload for curl request
        local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Payload:)%f" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Response:)%f" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "%F{$info_color}$clean_text%f\n"
    else
        # Print thinking message
        print -Pn "%F{$think_color}Thinking...%f\r"

        local user_prompt="$1"

        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}get info about: $1%f\n"
        fi

        # Construct json payload for curl request
        local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Payload:)%f" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Response:)%f" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "%F{$info_color}$clean_text%f\n"
    fi
}

function _hey_widget() {
    # Strip 'hey ' from the current line buffer
    # print "$@"
    # print $#
    local input="${@#hey }"
    if [[ $debug == 1 ]]; then
        print -Pn "\e[31m( Input: )\e[0m" "$input" "\n"
    fi
    if (( $# >= 1 )); then
        if [[ $2 == "-i" ]]; then
            local input_stripped="${input#-- }"
            local input_stripped_flag="${input_stripped#-i}"
            _hey_info "$input_stripped_flag"
        else
            _hey_logic "$input"
        fi
    fi
}

# Register the ZLE widget
zle -N _hey_widget

# Alias for easy access
alias hey='_hey_widget'