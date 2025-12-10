# 🚀 JayantsList API Documentation

This documentation details the API endpoints for the JayantsList application. It is designed to be used alongside the provided Postman Collection (`JayantsList_API_Tests.postman_collection.json`).

## 📥 How to Use
1. **Import Collection**: Open Postman -> File -> Import -> Upload `JayantsList_API_Tests.postman_collection.json`.
2. **Environment Variables**: The collection uses the following variables:
   - `{{base_url}}`: `https://www.jayantslist.com`
   - `{{auth_token}}`: Automatically set after running the "Validate OTP" request.

---

## 🔐 1. Authentication

### 1.1 Send OTP
Generates a One-Time Password (OTP) for the provided mobile number.

- **URL**: `{{base_url}}/api/accounts/send-otp`
- **Method**: `POST`
- **Status**: ✅ Working

**Request Body:**
```json
{
  "mobile": "9675789818"
}
```

**Success Response (200 OK):**
```json
{
  "otp": "123456"
}
```

### 1.2 Validate OTP
Verifies the OTP and returns an authentication token.
*Note: This request automatically saves the `auth_token` to your Postman environment variables.*

- **URL**: `{{base_url}}/api/accounts/validate-otp`
- **Method**: `POST`
- **Status**: ✅ Working

**Request Body:**
```json
{
  "mobile": "9675789818",
  "otp": "123456"
}
```

**Success Response (200 OK):**
```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
  "user_account": {
    "id": "2",
    "mobile_no": "9675789818",
    "fullname": "Guest",
    "roles": ["BUYER"]
  }
}
```

---

## 📍 2. Location

### 2.1 Update Last Location
Updates the user's current latitude and longitude. Required for "Nearby Sellers" to work.

- **URL**: `{{base_url}}/api/accounts/update-last-location`
- **Method**: `POST`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Status**: ✅ Working

**Request Body:**
```json
{
  "latitude": 26.4499,
  "longitude": 80.3319
}
```

**Success Response (200 OK):**
*(Empty Body)*

---

## 🏷️ 3. Categories

### 3.1 Get Root Categories
Fetches the top-level categories.

- **URL**: `{{base_url}}/api/sellers/categories`
- **Method**: `GET`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Status**: ⚠️ Partial Data (Returns empty list in some environments)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "categories": []
  }
}
```

### 3.2 Get Subcategories
Fetches children of a specific category.

- **URL**: `{{base_url}}/api/sellers/categories?parent_id=1`
- **Method**: `GET`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Status**: ✅ Working (Data may vary from documentation)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "2",
        "name": "Fruits",
        "hcode": "1.1",
        "shops_count": "1"
      }
    ]
  }
}
```

---

## 🏪 4. Seller Discovery (⚠️ Currently Unstable)

### 4.1 Get Nearby Sellers
Finds sellers within a specific radius.

- **URL**: `{{base_url}}/api/sellers/nearby-sellers`
- **Method**: `GET`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Query Params**:
  - `max_distance`: (Optional) Distance in km (e.g., `10`)
  - `category`: (Optional) Category ID
  - `lat`: (Optional) Latitude override
  - `lon`: (Optional) Longitude override
- **Status**: 🔴 **Broken** (Returns 500 Internal Server Error)

**Error Response (500 Internal Server Error):**
```
Internal Server Error
```

### 4.2 Search Shops
Search for shops by name or description.

- **URL**: `{{base_url}}/api/sellers/search`
- **Method**: `GET`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Query Params**:
  - `q`: Search term (e.g., `electrical`)
- **Status**: 🔴 **Broken** (Returns 500 Internal Server Error)

---

## 📌 5. User Actions (⚠️ Currently Unstable)

### 5.1 Pin Seller
Adds a seller to the user's pinned list.

- **URL**: `{{base_url}}/api/accounts/pin-seller`
- **Method**: `POST`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Status**: 🔴 **Broken** (Returns 500 Internal Server Error)

**Request Body:**
```json
{
  "seller_id": 1
}
```

---

## 📝 6. Seller Posts (⚠️ Currently Unstable)

### 6.1 Create Post
Allows a seller to post text, image, or video content.

- **URL**: `{{base_url}}/api/sellers/sellers/posts`
- **Method**: `POST`
- **Headers**: `Authorization: Bearer {{auth_token}}`
- **Status**: 🔴 **Broken** (Returns 500 Internal Server Error)

**Request Body:**
```json
{
  "media_type": "TEXT",
  "caption": "New stock available!"
}
```
