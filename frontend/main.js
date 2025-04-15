// This function is called when the form is submitted
console.log("✅ main.js is loaded!");

document.getElementById('orderForm').addEventListener('submit', async function(event) {
    event.preventDefault(); // Prevent form from submitting the traditional way

    // Collecting the form data
    let customerId = document.getElementById('customerId').value;
    const productId = document.getElementById('productId').value;
    let quantity = document.getElementById('quantity').value;
    const orderDate = document.getElementById('orderDate').value;

    // Validate that all fields are filled
    if (!customerId || !productId || !quantity || !orderDate) {
        alert('Please fill in all the fields.');
        return;
    }

    //Validate that the customerId is a positive integer
    customerId = parseInt(customerId);
    if (isNaN(customerId) || customerId <= 0) {
        alert('Please enter a valid customer id.');
        return;
    }

    // Validate quantity (check if it's a valid positive number)
    quantity = parseInt(quantity);
    if (isNaN(quantity) || quantity <= 0) {
        alert('Please enter a valid quantity.');
        return;
    }

    // Prepare the data to send to the API
    const orderData = {
        customer_id: customerId,
        product_id: productId,
        quantity: quantity,
        order_date: orderDate
    };

    try {
        console.log("Sending API request with data:", JSON.stringify(orderData));
        // Send the data to the API gateway
        const response = await fetch('https://1qs4zjuptg.execute-api.us-east-1.amazonaws.com/dev/ordersubmission', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(orderData)
        });

        // Log the response status for debugging
        console.log("Response status:", response.status);

        if (response.ok) {
            const result = await response.json();
            alert(`Order Placed Successfully!\n\nThank you for your order!`);
            // Reset the form after successful submission
            document.getElementById('orderForm').reset();
        } else {
            const error = await response.json();
            alert(`Failed to place order: ${error.message || 'An unknown error occurred'}`);
        }
    } catch (error) {
        alert(`An error occurred: ${error.message || 'An unknown error occurred'}`);
    }
});
const productSelect = document.getElementById('productId');
const productImage = document.getElementById('productImage');

const productImages = {
    apple: 'images/apple.jpg',
    banana: 'images/banana.jpg',
    orange: 'images/orange.jpg',
    grapes: 'images/grapes.jpg',
};

productSelect.addEventListener('change', function () {
    const selected = productSelect.value;
    if (productImages[selected]) {
        productImage.src = productImages[selected];
        productImage.alt = selected;
        productImage.style.display = 'block';
    } else {
        productImage.style.display = 'none';
    }
});
