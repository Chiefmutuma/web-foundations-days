// Select the elements
const loadBtn = document.querySelector("#load-users");
const filterInput = document.querySelector("#filter-input");
const statusMessage = document.querySelector("#status");
const usersList = document.querySelector("#users-list");

const USERS_URL = "https://jsonplaceholder.typicode.com/users";

// The loaded users are stored here, so filtering does not need a new request
let users = [];

// Draws any array of users on the page
function renderUsers(list) {
  usersList.replaceChildren();

  for (const user of list) {
    const item = document.createElement("li");
    item.className = "user";

    const name = document.createElement("h3");
    name.textContent = user.name;

    const email = document.createElement("p");
    email.textContent = user.email;

    const city = document.createElement("p");
    city.textContent = `City: ${user.address.city}`;

    const company = document.createElement("p");
    company.textContent = `Company: ${user.company.name}`;

    item.append(name, email, city, company);
    usersList.appendChild(item);
  }
}

// Shows only the users whose name contains the typed text (not case-sensitive)
function applyFilter() {
  const term = filterInput.value.trim().toLowerCase();
  const filtered = users.filter((user) => user.name.toLowerCase().includes(term));

  renderUsers(filtered);

  if (users.length > 0 && filtered.length === 0) {
    const message = document.createElement("li");
    message.textContent = "No users match your filter.";
    usersList.appendChild(message);
  }
}

// Fetches the users, then shows them or an error message
async function loadUsers() {
  loadBtn.disabled = true;
  statusMessage.textContent = "Loading users...";

  try {
    const response = await fetch(USERS_URL);

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    users = await response.json();
    applyFilter();
    statusMessage.textContent = `Loaded ${users.length} users.`;
  } catch (error) {
    statusMessage.textContent = "Could not load users. Please try again.";
    console.error(error);
  } finally {
    loadBtn.disabled = false;
  }
}

// Load the users when the button is clicked
loadBtn.addEventListener("click", loadUsers);

// Filter the stored users on every keystroke, without a new request
filterInput.addEventListener("input", applyFilter);
