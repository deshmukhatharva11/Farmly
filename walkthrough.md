# Farmly Setup Walkthrough

## Setup Overview
I have successfully configured the environment and installed all necessary dependencies for the **Farmly** project (formerly KisanSahayak). The application consists of three main components: Backend, Frontend, and ML service.

## Prerequisites
- **Node.js**: Required for Backend and Frontend.
- **Python**: Required for ML service.
- **MongoDB**: Must be running locally on `mongodb://localhost:27017`.
- **Redis**: Optional. The backend now supports an in-memory fallback if Redis is not available.

## Configuration Created
I have created the following configuration files:
- **Backend**: `backend/.env` with default ports and database URLs.
- **Frontend**: `frontend/.env` pointing to the backend API.

## Project Structure & Documentation
I have generated README files for each component:
- **Root**: Project overview and quick start.
- **Backend**: API and database details.
- **Frontend**: UI development and environment variables.
- **ML**: Model details and python requirements.

## How to Run the Application

You need to run three separate terminals to start the full application:

### 1. Backend Server
```bash
cd backend
npm start
```
*Expected Output:* "Server listening on PORT: 5000", "Connected to MongoDB".
*Note:* If Redis is not running, you will see "Redis connection error... Using in-memory Redis mock".

### 2. Frontend Application
```bash
cd frontend
npm run dev
# OR for mobile access:
npx vite --host
```
*Access:* 
- **Local:** [http://localhost:5173](http://localhost:5173)
- **Mobile/Network:** [http://192.168.1.33:5173](http://192.168.1.33:5173)

### 3. Machine Learning Service
```bash
cd ML
uvicorn app:app --reload --port 8000
```
*Expected Output:* "Uvicorn running on http://127.0.0.1:8000"

## Mobile Access Instructions
1.  Ensure your mobile device is connected to the same Wi-Fi network as your computer.
2.  Open your mobile browser (Chrome, Safari, etc.).
3.  Navigate to: **[http://192.168.1.33:5173](http://192.168.1.33:5173)**
4.  You should see the application login page "Farmly".

## Frontend Enhancement Tips

Here are some recommendations to improve the **Farmly** frontend (React + Vite + Tailwind):

### 1. Performance Optimization
-   **Lazy Loading**: Use `React.lazy()` and `Suspense` for route-based code splitting. This will reduce the initial bundle size.
    ```jsx
    const Dashboard = React.lazy(() => import('./pages/dashboard/Dashboard'));
    ```
-   **Image Optimization**: Convert static images to WebP format. Use `vite-plugin-image-optimizer` to automatically compress assets.
-   **Virtualization**: If displaying large lists (e.g., marketplace items, history), use `react-window` or `react-virtualized` to render only visible items.

### 2. UI/UX Improvements
-   **Consistent Design System**: Create reusable Tailwind components (buttons, cards, inputs) in `src/components/ui/` to ensure visual consistency.
-   **Loading States**: Replace full-screen spinners with "Skeleton Loaders" (like `react-loading-skeleton`) for a smoother perceived load time.
-   **Mobile Responsiveness**: Test extensively on mobile. Use Tailwind's `md:` and `lg:` prefixes strictly to ensure layouts adapt to smaller screens (e.g., changing grid columns from 3 to 1).
-   **Dark Mode**: Implement a dark mode toggle using Tailwind's `dark:` modifier.

### 3. Code Quality & Architecture
-   **Custom Hooks**: Extract logic from components into custom hooks (e.g., `useFetchData`, `useFormSubmit`) to keep UI components clean.
-   **Absolute Imports**: Configure Vite to allow absolute imports (e.g., `import Button from '@/components/Button'`) to avoid `../../` hell.
-   **Error Boundary**: Wrap the application in an Error Boundary to catch crashes gracefully and display a "Something went wrong" UI instead of a white screen.

### 4. Accessibility (a11y)
-   **Semantic HTML**: Use `<main>`, `<section>`, `<article>` instead of `<div>` where appropriate.
-   **ARIA Labels**: Ensure all interactive elements (buttons with icons, form inputs) have `aria-label` or associated `<label>` tags.
