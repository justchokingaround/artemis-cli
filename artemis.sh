#!/bin/sh

get_credentials() {
  username=$(grep -s username ~/.config/artemis/artemis_secrets.txt|cut -d ':' -f2)
  password=$(grep -s password ~/.config/artemis/artemis_secrets.txt|cut -d ':' -f2)
  [ -z "$username" ] || [ -z "$password" ] && set_credentials && get_credentials
  bearer=$(curl -s -X POST 'https://artemis.ase.in.tum.de/api/authenticate' -H 'Content-Type: application/json' \
  --data-raw '{"username":"'"$username"'","password":"'"$password"'","rememberMe":true}'|
  sed -nE 's@.*"id_token":"([^"]*)".*@\1@p')
  [ -z "$bearer" ] && echo "Authentication failed" && set_credentials
}

set_credentials() {
  printf "There was a problem with getting your credentials.\n"
  printf "Please enter your Artemis username: " && read -r username
  printf "Please enter your Artemis password (the input is hidden): " && stty -echo && read -r password && stty echo
  [ ! -d ~/.config/artemis ] && mkdir ~/.config/artemis 
  [ -f ~/.config/artemis/artemis_secrets.txt ] && rm -f ~/.config/artemis/artemis_secrets.txt
  echo "username:$username" >> ~/.config/artemis/artemis_secrets.txt
  echo "password:$password" >> ~/.config/artemis/artemis_secrets.txt
  printf "\nYour credentials have been stored in ~/.config/artemis/artemis_secrets.txt\n" && sleep 2
}

start_menu() {
  tput clear
  choice=$(printf "Dashboard\nAccount\nNotifications\n"|fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$choice" in
    Dashboard)
      dashboard_menu
      ;;
    Account)
      account_menu
      ;;
    Notifications)
      notifications_menu
      ;;
  esac
}

notifications_menu() {
  # notifications=$(curl -s 'https://artemis.ase.in.tum.de/api/notifications?sort=notificationDate,desc' \
  #   -H "Authorization: Bearer $bearer"|tr '{|}' '\n'|tr -d "\\"|
  #   sed -nE 's_.*"id":([0-9]*),.*"text":"(.*)".*"notificationDate":"([^"]*)".*_\1\t\2\t\3_p'|
  #   fzf --height=20% --reverse --prompt="Select a notification: " --cycle --with-nth=2..)
  printf "This section is under construction.\n" && sleep 2
}

account_menu() {
  choice=$(printf "Registration Number\nEmail\nID\n"|fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$choice" in
    "Registration Number")
      printf "Here is your registration number: %s\n" "$(curl -s 'https://artemis.ase.in.tum.de/api/account' \
        -H "Authorization: Bearer $bearer"|
        sed -nE 's@.*"visibleRegistrationNumber":"([0-9]*)".*@\1@p')"
      printf "Do you want to continue? (y/n) " && read -r yn
      [ -z "$yn" ] || [ "$yn" = "y" ] || [ "$yn" = "Y" ] && start_menu
      ;;
    Email)
      # TODO: rewrite better regex
      printf "Here is your email: %s\n" "$(curl -s 'https://artemis.ase.in.tum.de/api/account' \
        -H "Authorization: Bearer $bearer"|
        sed -nE 's@.*"email":"([^"]*)".*@\1@p')"
      printf "Do you want to continue? (y/n) " && read -r yn
      [ -z "$yn" ] || [ "$yn" = "y" ] || [ "$yn" = "Y" ] && start_menu
      ;;
    ID)
      printf "Here is your ID: %s\n" "$(curl -s 'https://artemis.ase.in.tum.de/api/account' \
        -H "Authorization: Bearer $bearer"|
        sed -nE 's@.*"id":([0-9]*),.*@\1@p')"
      printf "Do you want to continue? (y/n) " && read -r yn
      [ -z "$yn" ] || [ "$yn" = "y" ] || [ "$yn" = "Y" ] && start_menu
      ;;
  esac
}


dashboard_menu() {
  choice=$(printf "Intro to SE\nOS\n"|fzf --height=20% --reverse --prompt="Select a course: ")
  [ -z "$choice" ] && exit 1
  case "$choice" in
    "Intro to SE")
      course_id="185"
      ;;
    OS)
      course_id="173"
      ;;
  esac
  course_menu
}

course_menu() {
  course_choice=$(printf "Exercises\nLectures\n"|fzf --height=20% --reverse --prompt="Select a course: ")
  [ -z "$course_choice" ] && exit 1
  case "$course_choice" in
    Exercises)
      while true; do
        set -e
        exercises_menu
      done
      ;;
    Lectures)
      lectures_menu
      ;;
  esac
}

exercises_menu() {
  # TODO: format date ig
  exercises=$(curl -s "https://artemis.ase.in.tum.de/api/courses/${course_id}/for-dashboard" -H "Authorization: Bearer $bearer"|
    tr '{|}' '\n'|sed -n '/^.*exercises/,/^.*lectures/{p;/^.*lectures/q;}'|
    sed -nE 's_.*"type":"([^"]*)","id":([0-9]*),"title":"([^"]*)",.*"dueDate":"([^"]*)".*_\1\t\2\t\3 / Due Date: \4_p')

  all_exercises=$(printf "%s\n" "$exercises"|
    grep -E '^(programming|text|file-upload|modeling|quiz)')
  exercise_count=$(printf "%s" "$all_exercises"|wc -l|sed 's/ //g')
  exercise_type=$(printf "All Exercises\nProgramming\nText\nFile Upload\nModeling\nQuiz\n"|
    fzf --height=20% --reverse --prompt="Select an exercise type: " --cycle|tr " " "-"|tr "[:upper:]" "[:lower:]")
  if [ "$exercise_type" = "all-exercises" ]; then
    exercise_choice=$(printf "%s\n" "$all_exercises"|sort -rk2|
      fzf --with-nth 3.. --height=20% --reverse --prompt="Select one of the ${exercise_count} exerices available: " --cycle)
    exercise_type=$(printf "%s\n" "$exercise_choice"|cut -f1)
    exercise_id=$(printf "%s\n" "$exercise_choice"|cut -f2)
  else
    exercise_id=$(printf "%s\n" "$all_exercises"|grep -E "^$exercise_type"|sort -rk2|
      fzf --with-nth 3.. --height=20% --reverse --prompt="Select an exercise: " --cycle|cut -f2)
  fi
  [ -z "$exercise_id" ] && printf "There was a problem with getting the exercise id\n" && exit 1

  exercise_url=$(curl -s "https://artemis.ase.in.tum.de/api/exercises/${exercise_id}/participations" \
    -H "Authorization: Bearer $bearer" -H 'Content-Type: text/plain' --data-raw '{}')

  exercise_menu
}

lectures_menu() {
  lectures=$(curl -s "https://artemis.ase.in.tum.de/api/courses/${course_id}/for-dashboard" -H "Authorization: Bearer $bearer"|
    tr '{|}' '\n'|sed -n '/^.*lectures/,/^.*validStartAndEndDate/{p;/^.*validStartAndEndDate/q;}'|
    sed -nE 's_.*"id":([0-9]*),"title":"([^"]*)".*_\1\t\2_p')
  lecture_id=$(printf "%s\n" "$lectures"|sort -r|
    fzf --with-nth 2.. --height=20% --reverse --prompt="Select a lecture: " --cycle|cut -f1)
  printf "This section is not yet implemented yet, here is the link to the lecture:\n"
  printf "https://artemis.ase.in.tum.de/courses/%s/lectures/%s\n" "$course_id" "$lecture_id"
}

exercise_menu() {
  exercise_json=$(printf "%s" "$exercise_url")
  case $exercise_type in
    programming)
      programming_exercise_menu
      ;;
    text)
      text_exercise_menu
      ;;
    file-upload)
      file_upload_exercise_menu
      ;;
    modeling)
      modeling_exercise_menu
      ;;
    quiz)
      quiz_exercise_menu
      ;;
  esac
}

programming_exercise_menu() {
  exercise_info_to_get=$(printf "Problem Statement\nRepository Url"|
    fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$exercise_info_to_get" in
    "Problem Statement")
      printf "%s" "$exercise_json"|
        sed -nE 's_.*"problemStatement":"([^"]*)".*_\1_p'|sed -e 's/\\n/\n/g' \
        -e 's/\\"/\"/g' -e 's/<br>/\n/g'|fold -s -w 120|less
      ;;
    "Repository Url")
      printf "This section is not yet implemented yet..."
      # repo_url=$(printf "%s" "$exercise_json"|sed -nE 's_.*"repositoryUrl":"([^"]*)".*_\1_p')
      # printf "Here is the repository url: %s\n" "$repo_url"
      # while true; do
      #     set -e
      #     printf "Do you want to clone the repository? (y/n) "
      #     IFS= read -r yn < /dev/tty
      #     [ -z "$yn" ] && yn="y"
      #     case "$yn" in
      #       [Yy]* ) git clone "$repo_url"; break;;
      #       [Nn]* ) break;;
      #       * ) printf "Please answer yes or no.\n";;
      #     esac
      # done
      ;;
  esac
}

text_exercise_menu() {
  exercise_info_to_get=$(printf "Problem Statement\nSubmission Text"|
    fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$exercise_info_to_get" in
    "Problem Statement")
      printf "%s" "$exercise_json"|
        sed -nE 's_.*"problemStatement":"([^"]*)".*_\1_p'|sed -e 's/\\n/\n/g' \
        -e 's/\\"/\"/g' -e 's/<br>/\n/g'|fold -s -w 120|less
      ;;
    "Submission Text")
      submission_content=$(printf "%s" "$exercise_json"|
        sed -nE 's_.*"text":"([^"]*)".*_\1_p'|sed -e 's/\\n/\n/g' \
        -e 's/\\"/\"/g' -e 's/<br>/\n/g')
      if [ -z "$submission_content" ]; then
        printf "There was a problem with getting the submission text\n"
      else
        printf "%s" "$submission_content"|less
      fi
      ;;
  esac
}

file_upload_exercise_menu() {
  exercise_info_to_get=$(printf "Problem Statement\nSubmission File"|
    fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$exercise_info_to_get" in
    "Problem Statement")
      printf "%s" "$exercise_json"|
        sed -nE 's_.*"problemStatement":"([^"]*)".*_\1_p'|sed -e 's/\\n/\n/g' \
        -e 's/\\"/\"/g' -e 's/<br>/\n/g'|fold -s -w 120|less
      ;;
    "Submission File")
      file_url=$(printf "%s" "$exercise_json"|
        sed -nE 's_.*"filePath":"([^"]*)".*_\1_p')
      if [ -z "$file_url" ]; then
        printf "There was a problem with getting the submission file\n"
      else
        printf "https://artemis.ase.in.tum.de%s\n" "$file_url"
      fi
      ;;
  esac
}

modeling_exercise_menu() {
  exercise_info_to_get=$(printf "Problem Statement\nSubmission Model\nSubmission Explanation Text"|
    fzf --height=20% --reverse --prompt="Select an action: " --cycle)
  case "$exercise_info_to_get" in
    "Problem Statement")
      printf "%s" "$exercise_json"|
        sed -nE 's_.*"problemStatement":"(.*)","presentationScoreEnabled".*_\1_p'|sed -e 's/\\n/\n/g' \
        -e 's/<br>/\n/g'|fold -s -w 120|less
      ;;
    "Submission Model")
      model_json=$(printf "%s" "$exercise_json"|
        sed -nE 's_.*"model":"(.*)","explanationText".*_\1_p')
      if [ -z "$model_json" ]; then
        printf "There was a problem with getting the submission model's json\n"
      else
        printf "%s\n" "$model_json"
      fi
      ;;
    "Submission Explanation Text")
      explanation_text=$(printf "%s" "$exercise_json"|
        sed -nE 's_.*"explanationText":"(.*)","empty".*_\1_p')
      if [ -z "$explanation_text" ]; then
        printf "There was a problem with getting the submission explanation text\n"
      else
        printf "%s\n" "$explanation_text"|sed 's/\\"/\"/g'
      fi
      ;;
  esac
}

quiz_exercise_menu() {
  printf "%s" "$exercise_json"|tr "{|}" "\n"
  }

get_credentials
while true; do
  set -e
  start_menu
done

