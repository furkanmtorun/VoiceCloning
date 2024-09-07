// VoiceCloning

// HARDCODED:
// const BASE_API_URL = "https://d20hbh58zkqtxv.cloudfront.net/projects"
const BASE_API_URL =
  "https://l481bschml.execute-api.eu-central-1.amazonaws.com/api/projects";
const projectsContainer = $("#projectsContainer");
const S3_OUTPUT_URL =
  "https://voicecloning-outputs.s3.eu-central-1.amazonaws.com/";

// ########################
// ####### General ########
// ########################
$(document).ready(function () {
  if (
    window.location.pathname === "/" ||
    window.location.pathname === "/website/"
  ) {
    // Main (Home) Page
    fetchProjects();
    projectsContainer.on("click", "a", function (event) {
      const projectId = $(this).attr("project_id");
      if (projectId != "-1") {
        event.preventDefault();
        fetchProjectDetails(projectId);
      }
    });
  }
  // else if (window.location.pathname === '/create.html' || window.location.pathname === '/website/create.html') {
  //     // Project Create Page
  // }
});

// ##################################
// ###### Project Create Form #######
// ##################################
document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("projectForm");
  const submitButton = document.getElementById("submitButton");

  // Function to check form validity and update submit button
  function checkFormValidity() {
    if (form.checkValidity()) {
      submitButton.classList.remove("disabled");
      submitButton.disabled = false;
    } else {
      submitButton.classList.add("disabled");
      submitButton.disabled = true;
    }
  }

  // Initial check to disable button if form is not valid on page load
  checkFormValidity();

  // Add event listeners to all form inputs to check validity on change
  const inputs = form.querySelectorAll("input, select, textarea");
  inputs.forEach((input) => {
    input.addEventListener("input", checkFormValidity);
  });

  // Handle form submission
  form.addEventListener("submit", function (event) {
    if (submitButton.classList.contains("disabled")) {
      event.preventDefault();
    } else {
      submitProjectForm(event); // Submit
    }
  });
});

// ########################
// ####### Fetching #######
// ########################
function fetchProjects() {
  $.ajax({
    url: BASE_API_URL,
    type: "GET",
    success: function (response) {
      displayProjects(response);
    },
    error: function () {
      displayError();
    },
  });
}

function fetchProjectDetails(projectId) {
  $.ajax({
    url: BASE_API_URL + "/" + projectId,
    type: "GET",
    success: function (response) {
      displayProjectPopup(response);
    },
    error: function () {
      displayError();
    },
  });
}

// ########################
// ####### Displays #######
// ########################
function displayProjects(projects) {
  projects.forEach(function (project) {
    const projectCard = createProjectCard(project);
    projectsContainer.append(projectCard);
  });
}

function createProjectCard(project) {
  return `
        <a href="#" project_id="${project.id}" class="project-card">
            <img src="avatar.png" alt="Project Avatar" class="avatar">
            <div class="card-content">
                <h3>${project.title}</h3>
                <p>Quality: ${project.quality} | ${project.created_at}</p>
                <!-- <p class="progress-label ${project.progress}">${project.progress}</p> -->
            </div>
        </a>
    `;
}

function displayProjectPopup(project) {
  // Create the popup HTML
  const popupContent = `
        <div class="popup-overlay"></div>
        <div class="popup-container">
            <h2>${project.title}</h2>
            <p><b>Text:</b> ${project.text}</p>
            <p><b>Quality:</b> ${project.quality}</p>
            <p><b>Created at:</b> ${project.created_at}</p>
            <p><b>Description:</b> ${project.description}</p>
            <!-- <p><b>Progress:</b> ${project.progress}</p> -->
            <p><b>Uploaded audio files:</b> ${project.audio_files}</p>
            <p><b>Cloned voice:</b></p>
            <audio controls autoplay>
                <source src="${S3_OUTPUT_URL}/${project.id}.wav" type="audio/wav">
                Your browser does not support the audio element.
            </audio>
            <button class="close-popup">Close</button>
        </div>
    `;
  // Append the popup to the body
  $("body").append(popupContent);

  // Event listener for closing the popup
  $("body").on("click", ".close-popup, .popup-overlay", function () {
    $(".popup-container, .popup-overlay").remove();
  });
}

function displayError() {
  alert("Error fetching data");
}

// ########################
// ####### Posting ########
// ########################

function createProject(formData) {
  return new Promise(function (resolve, reject) {
    $.ajax({
      url: BASE_API_URL,
      type: "POST",
      data: formData,
      processData: false, // Prevent jQuery from transforming the data into a query string
      contentType: false, // Allow the browser to set the content type to multipart/form-data
      success: function (data) {
        resolve(data);
      },
      error: function (xhr, status, error) {
        console.log(error);
        return error;
      },
    });
  });
}

function submitProjectForm(event) {
  event.preventDefault(); // Prevent default form submission behavior
  var formData = new FormData(document.getElementById("projectForm"));

  createProject(formData)
    .then(function (data) {
      alert("Success: The voice is being cloned!");
      window.location.href = "../"; // Redirect to the root page
    })
    .catch(function (error) {
      // Handle error
      alert("Error: " + error);
      // window.location.reload(); // Refresh the page
    });
}
