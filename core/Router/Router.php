<?php

namespace Core\Router;

use Core\Constants\Constants;
use Core\Exceptions\HTTPException;
use Core\Http\Request;
use Exception;

class Router
{
    private static Router|null $instance = null;
    /** @var Route[] $routes */
    private array $routes = [];

    private function __construct()
    {
    }

    private function __clone()
    {
    }

    public static function getInstance(): Router
    {
        if (self::$instance === null) {
            self::$instance = new Router();
        }

        return self::$instance;
    }

    public static function reset(): void
    {
        self::$instance = null;
    }

    public function addRoute(Route $route): Route
    {
        $this->routes[] = $route;
        return $route;
    }

    public function getRouteSize(): int
    {
        return sizeof($this->routes);
    }

    public function getRoute(int $index): Route
    {
        return $this->routes[$index];
    }

    /**
     * @param string $name
     * @param mixed[] $params
     * @return string
     */
    public function getRoutePathByName(string $name, array $params = []): string
    {
        foreach ($this->routes as $route) {
            if ($route->getName() === $name) {
                $routePath = $route->getUri();
                $routePath = $this->replaceRouteParams($routePath, $params);
                $routePath = $this->appendQueryParams($routePath, $params);

                return $routePath;
            }
        }

        throw new Exception("Route with name $name not found", 500);
    }

    /**
     * @param string $routePath
     * @param mixed[] $params
     * @return string
     */
    private function replaceRouteParams(string $routePath, &$params): string
    {
        foreach ($params as $param => $value) {
            $routeParam = '{' . $param . '}';
            if (strPos($routePath, $routeParam) !== false) {
                $routePath = str_replace($routeParam, $value, $routePath);
                unset($params[$param]);
            }
        }

        return $routePath;
    }

    /**
     * @param string $routePath
     * @param mixed[] $params
     * @return string
     */
    private function appendQueryParams(string $routePath, $params): string
    {
        if (!empty($params)) {
            $routePath .= '?' . http_build_query($params);
        }
        return $routePath;
    }

    public function dispatch(): object|bool
    {
        $request = new Request();

        foreach ($this->routes as $route) {
            if ($route->match($request)) {
                $route->runMiddlewares($request);

                $class = $route->getControllerName();
                $action = $route->getActionName();

                $controller = new $class();
                $controller->$action($request);

                return $controller;
            }
        }
        return throw new HTTPException('URI ' . $request->getUri() . ' not found.', 404);
    }

    public static function init(): void
    {
        if (isset($_SERVER['REQUEST_METHOD'])) {
            require Constants::rootPath()->join('config/routes.php');
            Router::getInstance()->dispatch();
        }
    }
}
